#!/bin/bash

SSH=/usr/bin/ssh
USER=tsujio
HOST=serv1.tsujio.org
KEY=/id_rsa

if [ $# -lt 1 ]; then
    echo "Usage: $0 REPOSITORY_NAME"
    exit 1
fi

repository=$1

case ${repository} in
    "www" )
        options='-e VIRTUAL_HOST=www.tsujio.org' ;;
    "www-activity" )
        options='-e VIRTUAL_HOST=activity.tsujio.org \
                 -e GITHUB_TOKEN=`cat /home/tsujio/github-token`' ;;
    "www-github-webhook" )
        options='-e VIRTUAL_HOST=github-webhook.tsujio.org \
                 -e WEBHOOK_SECRET=`cat /home/tsujio/webhook-secret` \
                 -v /home/tsujio/id_rsa.github-webhook:/id_rsa:ro' ;;
    * )
        options='' ;;
esac

$SSH -i $KEY $USER@$HOST bash <<EOF

cid=`docker ps | grep '^[0-9a-f]+\s+${repository}\s+' | head -n 1 | cut -d' ' -f1`
if [ -n "$cid" ]; then
    echo "container not found"
    exit 1
fi

cd /home/tsujio/repo/${repository} || exit 1

git pull origin master || exit 1

docker build -t ${repository} . || exit 1

docker stop $cid || exit 1

docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    ${options} \
    ${repository} || exit 1

EOF
