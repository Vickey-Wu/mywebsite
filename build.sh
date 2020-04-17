rm -rf ${PWD}/public
docker run --rm -it -v ${PWD}:/src -p 1313:1313 vijaymateti/hugo:latest hugo
docker restart mynginx
