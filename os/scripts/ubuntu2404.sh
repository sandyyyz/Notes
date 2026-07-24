#!/bin/bash
docker ps -a | grep ${USER}_ubuntu2404 > /dev/null
if [ $? -eq 0 ]; then
        # the container has been created.
        docker ps -a | grep ${USER}_ubuntu2404 | grep "Exited (" > /dev/null
        if [ $? -eq 0 ]; then
                # The container has been exited, start it
                docker start -i ${USER}_ubuntu2404
        else
                # The container has been started, exec another one
                docker exec -it ${USER}_ubuntu2404 bash
        fi
else
        # create new container
        docker run --rm -it \
			-u $USER \
			-e HOME="/mnt/home/${USER}" \
			-p 127.0.0.1:1234:1234 \
			-v /mnt/lib:/mnt/lib \
			-v /mnt/repo:/mnt/repo \
			-v /mnt/home/$USER:/mnt/home/$USER \
			--name ${USER}_ubuntu2404 \
			ubuntu:24.04 bash
fi
