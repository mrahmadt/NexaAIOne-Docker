#!/bin/bash

# check to the current directory of this script
if [ ! -f install.sh ]; then
    echo "Please run this script from the root of the repository."
    exit 1
fi

# make sure git command is exist
if ! [ -x "$(command -v git)" ]; then
    echo "Please install git command."
    exit 1
fi

# make sure docker-compose command is exist
if ! [ -x "$(command -v docker-compose)" ]; then
    echo "Please install docker-compose command."
    exit 1
fi

# make sure docker command is exist
if ! [ -x "$(command -v docker)" ]; then
    echo "Please install docker command."
    exit 1
fi

# check if docker/NexaAIOne/.env is exist, if not, fetch from https://raw.githubusercontent.com/mrahmadt/NexaAIOne/main/.env.example and name it .env
if [ ! -f docker/NexaAIOne/.env ]; then
    echo "Fetching .env.example from https://raw.githubusercontent.com/mrahmadt/NexaAIOne/main/.env.example"
    curl https://raw.githubusercontent.com/mrahmadt/NexaAIOne/main/.env.example --output docker/NexaAIOne/.env --silent
    echo ""
    echo "Please edit docker/NexaAIOne/.env file"
    echo "Then run this script again"
    echo ""
    exit 1
fi

if grep -q 'OPENAI_API_KEY=""' docker/NexaAIOne/.env || grep -q 'OPENAI_API_KEY=$' docker/NexaAIOne/.env; then
echo ""
    echo "OPENAI_API_KEY is not set. Please set it in docker/NexaAIOne/.env file."
    echo ""
    exit 0
fi

if grep -q '^USER_PASSWORD=123456$' ./.env; then
    echo ""
    echo "WARNING: Your USER_PASSWORD is set to the default value of 123456."
    echo "Please change it in .env before continuing."
    echo ""
    exit 0
fi

# echo ""
# echo "=============================="
# echo "== Admin Portal Credentials =="
# echo "=============================="
# echo ""

# echo "Please enter the name of the admin:"
# read USER_NAME

# echo ""
# echo "A valid and unique email address:"
# read USER_EMAIL

# echo ""
# echo "Password for the admin (min. 8 characters):"
# read USER_PASSWORD


echo COMPANY=Company > .env
# echo USER_NAME=$USER_NAME >> .env
# echo USER_EMAIL=$USER_EMAIL >> .env
# echo USER_PASSWORD=$USER_PASSWORD >> .env
echo '' >> .env
cat docker/NexaAIOne/.env >> .env

echo ""
echo ""
echo "Running NexaAIOne (docker-compose)"
# docker-compose up -d --build
docker-compose build --no-cache
docker-compose up -d

# echo "Waiting for NexaAIOne to start"
# until docker-compose exec -T app php artisan --version > /dev/null 2>&1; do
#     sleep 1
# done
if [ $? -eq 0 ]; then
    echo ""
    echo ""
    echo "Success! log in at http://localhost/admin/login"
    echo ""
    echo ""
fi