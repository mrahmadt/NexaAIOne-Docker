#!/bin/bash

echo "Running NexaAIOne (docker-compose)"
docker-compose up -d 

# echo "Waiting for NexaAIOne to start"
# until docker-compose exec -T app php artisan --version > /dev/null 2>&1; do
#     sleep 1
# done

echo "Success! log in at http://localhost/admin/login"

echo ""
