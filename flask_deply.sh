
# The following is a Shell script to deploy and publish a Flask into a Docker container.
# Author: omrsangx

#!/bin/bash

# Global variables

REMOTE_USER=$1
REMOTE_HOST=$2
SSH_CRED=$(echo "$REMOTE_USER@$REMOTE_HOST")
CONTAINER_PORT=$3
DEV_DIR=$(echo "$(pwd)/*")
DEV_FILES=$4

REMOTE_ENV_DIR="/home/$REMOTE_USER/flask_virtual_env"
CONTAINER_ENV_DIR="/home/flask_virtual_env"
CONTAINER_PYTHON_FILE="$DEV_FILES" 

if [[ $REMOTE_USER == "-h" || $REMOTE_USER == "--help"  ]] ; then
    echo "Usage: flaskDepl.sh [remote_user] [remote_host] [container_port 9000 to 9999] [pwd] [Flask app files]"
    echo "Enter flaskDepl.sh -h or flaskDepl.sh --help for more info"    
    exit 0
    
elif [[ -z $REMOTE_USER && -z $REMOTE_HOST ]] ; then
    echo "Code ran unsuccessful"
    echo "Usage: flaskDepl.sh [remote_user] [remote_host] [container_port 9000 to 9999] [pwd] [Flask app files]"
    echo "Enter flaskDepl.sh -h or flaskDepl.sh --help for more info"
    # ./z_docker_flask.sh centos 192.168.5.200 9337 file 
    exit 1

elif [[ ! $CONTAINER_PORT =~ ^[0-9]+$ ]] || [[ $CONTAINER_PORT -lt 9000 || $CONTAINER_PORT -gt 9999 ]] ; then
    echo "Code ran unsuccessful"
    echo "Usage: flaskDepl.sh [remote_user] [remote_host] [container_port 9000 to 9999] [pwd] [Flask app files]"
    echo "Enter flaskDepl.sh -h or flaskDepl.sh --help for more info"    
    exit 1

elif [[ -z $DEV_FILES ]] ; then
    echo "Type the file that is being deployed"
    echo "Usage: flaskDepl.sh [remote_user] [remote_host] [container_port 9000 to 9999] [pwd] [Flask app files]"
    echo "Enter flaskDepl.sh -h or flaskDepl.sh --help for more info"    
    exit 1
fi

echo "Starting deployment "
echo "Directory being copied.........$DEV_DIR"
echo "File being copied..............$(pwd)/$DEV_FILES"
echo "Press enter to continue........"
read 
echo "Checks passed...............Running code"


# Create $REMOTE_ENV_DIR directory if it does not exit, otherwise delete all content:
ssh $SSH_CRED 'bash -s' << EOE
if [ ! -d $REMOTE_ENV_DIR ] ; then
    mkdir $REMOTE_ENV_DIR
else 
    rm -rf $REMOTE_ENV_DIR/*
fi
EOE


# Copying development file to remote server:
scp -r -C $DEV_DIR $SSH_CRED:$REMOTE_ENV_DIR/

# ***************************
# ****** Remote System ******
# ***************************

CHAINED_EXEC=$(cat << END
# Action done in the remote system:

# Docker shell commands to stop, remove, create, and start the flask_env container
docker container stop flask_env 
docker container rm flask_env 
docker run -it -d --name=flask_env -v $REMOTE_ENV_DIR:$CONTAINER_ENV_DIR -p $CONTAINER_PORT:$CONTAINER_PORT centos /bin/bash 
docker container start flask_env


# Creating the shell script that runs inside the container when the docker exec is ran

cat << EOF > $REMOTE_ENV_DIR/automate_flask_env.sh
#!/bin/bash 

# yum update -y 
yum install epel-release -y
# yum install vim -y 
yum install python3 -y
yum install python3-pip -y 

pip3 install --upgrade pip
pip3 install virtualenv 

mkdir /home/flask_app_env
cd /home/flask_app_env 
python3 -m venv /home/flask_app_env
source /home/flask_app_env/bin/activate

pip3 install --upgrade pip
pip3 install Flask wikipedia Jinja2 urllib3 matplotlib numpy

cd $CONTAINER_ENV_DIR/

FLASK_APP=$CONTAINER_ENV_DIR/$CONTAINER_PYTHON_FILE flask run --host=0.0.0.0 --port=$CONTAINER_PORT &

EOF

#chmod u+x $REMOTE_ENV_DIR/automate_flask_env.sh 
chmod 777 $REMOTE_ENV_DIR/automate_flask_env.sh 

# Executing command inside the container using docker exec CONTAINER_NAME SHELL_SCRIPT.sh
docker exec flask_env $CONTAINER_ENV_DIR/automate_flask_env.sh 

END
)

# *****************
# ****** SSH ******
# *****************

# ssh public key must already be in the remote host or it will ask for the remote system password
ssh $SSH_CRED 'bash -s' << EOT
$CHAINED_EXEC
EOT