#! /bin/bash

#
# A little script I use to run the Packer build because I like to have comments in
# my JSON (documenting what everything is). But, that's not allowed:
#
#   https://plus.google.com/+DouglasCrockfordEsq/posts/RK8qyGVaGSr
#
# The script prefers to use `strip-json-comments` but will still work if there is a
# JSON artifact from an earlier build around on the file system.
#

if [ "$DEBUG" = true ]; then
  PACKER_LOG_VALUE=true
fi

# Test to make sure we have the external variables we need
if [ ! -f vars.json ]; then
  cp example-vars.json vars.json
  echo "  Please edit the project's vars.json file before running this script"
  echo "   Leave the _password vars blank if you want them to be autogenerated"
  exit 1
fi

# Configure a particular Packer.io builder, if desired
if [ ! -z "$1" ]; then
  if [ "$1" == "amazon-ebs" ] || [ "$1" == "docker" ]; then
    BUILDER="-only=$1"
  elif [ "$1" == "validate" ]; then
    echo "Validating project's Packer.io configuration..."
    BUILDER="skip-build"
  else
    echo "  The requested Packer.io builder \"$1\" is not yet supported"
    echo "   Supported builders: 'amazon-ebs' and 'docker'"
    exit 1
  fi
fi

# Turn the URL for this git repository into a URL more fit for human consumption
function humanize-repo-url {
  if hash git 2>/dev/null; then
    GIT_REPO_URL=`git config --get remote.origin.url`

    if [[ $GIT_REPO_URL == git@* ]]; then
      GIT_REPO_URL="${GIT_REPO_URL/git@/https:\/\/}"
    fi

    if [[ $GIT_REPO_URL == *.git ]]; then
      GIT_REPO_URL="${GIT_REPO_URL/\.git/}"
    fi

    GIT_REPO_URL="${GIT_REPO_URL/github.com:/github.com/}"
  fi
}

# A temporary workaround until I get around to writing a docker-fig post-processor for Packer
function extract_from_json {
  export ${1}=`grep -Po "\"${2}\": ?\".*\",?" ${3}.json | sed "s/\"${2}\": \"//" | tr -d "\","`
}

# The main work of the script
function build_fcrepo3 {
  packer validate -var-file=vars.json fcrepo3.json

  # Looks to see if the vars file has any empty password variables; creates passwords if needed
  while read LINE; do
    if [ ! -z "$LINE" ]; then
      REPLACEMENT="_password\": \"`openssl rand -base64 12`\""

      # TODO: document what's going on with the automatic password generation stuff
      if [ ! -f .passwords ]; then
        PASSWORD_PATTERN="_password\": \"\""
      else
        PASSWORD_PATTERN="_password\": \"*\""
      fi

      NEWLINE="${LINE/$PASSWORD_PATTERN/$REPLACEMENT}"

      if [ "$NEWLINE" != "$LINE" ]; then
        touch .passwords
      fi

      echo $NEWLINE
    fi
  done <vars.json > vars.json.new
  mv vars.json.new vars.json

  # If we're not running in CI, use vars file; else, use ENV vars
  if [ -z "$CONTINUOUS_INTEGRATION" ]; then
    humanize-repo-url
    if [ ! -z "$GIT_REPO_URL" ]; then REPO_URL_VAR="--var packer_fcrepo3_repo=$GIT_REPO_URL"; fi

    # If we're running in debug mode, inform which repository we're building from
    if [ "$DEBUG" = true ] && [ ! -z "$GIT_REPO_URL" ]; then
      echo "Running new build checked out from $GIT_REPO_URL"
    fi

    if [ "$BUILDER" != "skip-build" ]; then
      PACKER_LOG=$PACKER_LOG_VALUE packer build $BUILDER $REPO_URL_VAR -var-file=vars.json fcrepo3.json

      # If we're running a docker build, create a fig.yml file (this is a workaround until a docker-fig post-processor exists)
      if [[ "$BUILDER" == *docker* ]]; then
        extract_from_json "DOCKER_USER" "docker_user" "vars"
        extract_from_json "TOMCAT_PORT" "tomcat_port" "vars"
        extract_from_json "TOMCAT_SSH_PORT" "tomcat_ssh_port" "vars"
        extract_from_json "FCREPO3_VERSION" "packer_fcrepo3_version" "fcrepo3"

        # Write out the simple fig.yml file
        if [ ! -z "$DOCKER_USER" ]; then
          echo "fcrepo3:" > fig.yml
          echo "  image: $DOCKER_USER/packer-fcrepo3:$FCREPO3_VERSION" >> fig.yml
          echo "  command: sudo /usr/bin/supervisord -c /etc/supervisor/supervisord.conf" >> fig.yml
          echo "  ports:" >> fig.yml
          echo "    - $TOMCAT_PORT:80" >> fig.yml
          echo "    - $TOMCAT_SSH_PORT:443" >> fig.yml
        else
          echo "Fig configuration not auto-generated because docker_user doesn't seem to be configured"
        fi
      fi
    fi
  else
    echo "Running within Travis, a continuous integration server"
    FCREPO3_ADMIN_PASSWORD=`openssl rand -base64 12`
    FCREPO3_DB_PASSWORD=`openssl rand -base64 12`
    MYSQL_ROOT_PASSWORD=`openssl rand -base64 12`
    KEYSTORE_PASSWORD=`openssl rand -base64 12`

    packer -machine-readable build \
      -var "fcrepo3_admin_password=${FCREPO3_ADMIN_PASSWORD}" \
      -var "fcrepo3_db_password=${FCREPO3_DB_PASSWORD}" \
      -var "mysql_root_password=${MYSQL_ROOT_PASSWORD}" \
      -var "keystore_password=${KEYSTORE_PASSWORD}" \
      fcrepo3.json | tee packer.log
  fi
}

# If we have strip-json-comments installed, use JSON source file; else use derivative
if hash strip-json-comments 2>/dev/null; then
  strip-json-comments packer-fcrepo3.json > fcrepo3.json
  build_fcrepo3
elif [ -f fcrepo3.json ]; then
  build_fcrepo3
else
  echo "  strip-json-comments needs to be installed to generate the fcrepo3.json file"
  echo "    For installation instructions, see https://github.com/sindresorhus/strip-json-comments"
fi
