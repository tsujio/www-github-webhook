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
        options='-e VIRTUAL_HOST=tsujio.org' ;;
    "www-activity" )
        options='-e VIRTUAL_HOST=activity.tsujio.org \
                 -e GITHUB_TOKEN=`cat /home/tsujio/github-token`' ;;
    "www-bingo" )
        options='-e VIRTUAL_HOST=bingo.tsujio.org' ;;
    "www-github-webhook" )
        options='-e VIRTUAL_HOST=github-webhook.tsujio.org \
                 -e WEBHOOK_SECRET=`cat /home/tsujio/webhook-secret` \
                 -v /home/tsujio/.ssh/id_rsa.github-webhook:/id_rsa:ro' ;;
    * )
        echo "unknown repository: ${repository}"; exit 1 ;;
esac

$SSH -i $KEY \
     -o StrictHostKeyChecking=no \
     -o UserKnownHostsFile=/dev/null \
     $USER@$HOST 'at now + 1 minute > /home/tsujio/webhook.log 2>&1' <<EOF

date

if [ ! -d /home/tsujio/repo/${repository} ]; then
    git clone https://github.com/tsujio/${repository}.git /home/tsujio/repo/${repository} || exit 1
fi

cid=\`docker ps | grep -E '^[0-9a-f]+\s+${repository}\s+' | head -n 1 | cut -d' ' -f1\`

cd /home/tsujio/repo/${repository} || exit 1

git checkout -- . || exit 1

git pull origin master || exit 1

docker build -t ${repository} . || exit 1

if [ -n "\$cid" ]; then
    docker stop \$cid || exit 1
fi

docker run -d \
    -v /etc/localtime:/etc/localtime:ro \
    ${options} \
    ${repository} || exit 1

EOF
