
#!/bin/bash

whoami
mkdir -p miniconda3
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda3/miniconda.sh
bash miniconda3/miniconda.sh -b -u -p miniconda3
rm miniconda3/miniconda.sh
miniconda3/bin/conda init bash
miniconda3/bin/conda init zsh
#source /home/ubuntu/.zshrc
source /home/ubuntu/.bashrc
# conda create -n myenv python=3.12 pip wheel
