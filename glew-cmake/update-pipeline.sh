fly set-pipeline -c pipeline.yml -p glew-cmake -t perlmint_ci --var "private-repo-key=$(sudo cat $1)"
