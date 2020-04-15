rm -rf /home/ubuntu/mywebsite/public
docker run --rm -it -v /home/ubuntu/mywebsite:/src -p 1313:1313 vijaymateti/hugo:latest hugo
docker restart mynginx
