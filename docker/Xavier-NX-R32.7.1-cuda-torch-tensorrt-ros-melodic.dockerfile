 # =============================================================================
 # Created on Mon Jun 12 2023 18:34:46
 # Author: Mukai (Tom Notch) Yu
 # Email: mukaiy@andrew.cmu.edu
 # Affiliation: Carnegie Mellon University, Robotics Institute, the AirLab
 #
 # Copyright Ⓒ 2023 Mukai (Tom Notch) Yu
 # =============================================================================

FROM --platform=linux/arm64 nvcr.io/nvidia/l4t-ml:r32.7.1-py3
ENV HOME_FOLDER=/root
WORKDIR ${HOME_FOLDER}/

# Fix apt install stuck problem
ENV DEBIAN_FRONTEND=noninteractive
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections

# update all obsolete packages to latest, install sudo, and cleanup
RUN apt update -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true && \
    apt full-upgrade -y && \
    apt install -y sudo && \
    apt autoremove -y && \
    apt autoclean -y

# fix local time problem
RUN apt install -y tzdata && \
    ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

# install python3 and pip3
RUN apt install -y python3-dev python3-pip python3-setuptools python3-wheel && \
    pip3 install --upgrade pip

# install python2 and pip2
RUN apt install -y python-dev python-pip python-setuptools python-wheel && \
    pip2 install --upgrade pip

# set default python version to 2
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python2 2 && \
    update-alternatives --set python /usr/bin/python2

# set default pip version to pip2
RUN update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip2 2 && \
    update-alternatives --set pip /usr/bin/pip2

# install some goodies
RUN apt install -y lsb-release apt-utils software-properties-common zsh unzip ncdu git less screen tmux tree locate perl net-tools vim nano emacs htop curl wget build-essential cmake ffmpeg

# install jtop
RUN sudo pip3 install -U jetson-stats

# copy all config files to home folder
COPY --from=home-folder-config ./. ${HOME_FOLDER}/

# install zsh, Oh-My-Zsh, and plugins
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.5/zsh-in-docker.sh)" -- \
    -t https://github.com/romkatv/powerlevel10k \
    -p git \
    -p https://github.com/zsh-users/zsh-autosuggestions \
    -p https://github.com/zsh-users/zsh-completions \
    -p https://github.com/zsh-users/zsh-syntax-highlighting \
    -p https://github.com/CraigCarey/gstreamer-tab \
    -a "[[ ! -f ${HOME_FOLDER}/.p10k.zsh ]] || source ${HOME_FOLDER}/.p10k.zsh" \
    -a "bindkey -M emacs '^[[3;5~' kill-word" \
    -a "bindkey '^H' backward-kill-word" \
    -a "autoload -U compinit && compinit" \
    -a "export LD_LIBRARY_PATH=/usr/local/lib/python3.6/dist-packages/torch/lib:/usr/lib/aarch64-linux-gnu/:/usr/local/lib/python3.6/dist-packages/torch_tensorrt/lib:${LD_LIBRARY_PATH}"

# Append libtorch, TensorRT, torch_tensorrt library path to LD_LIBRARY_PATH in bashrc
RUN echo "export LD_LIBRARY_PATH=/usr/local/lib/python3.6/dist-packages/torch/lib:/usr/lib/aarch64-linux-gnu/:/usr/local/lib/python3.6/dist-packages/torch_tensorrt/lib:${LD_LIBRARY_PATH}" >> ${HOME_FOLDER}/.bashrc

# change default shell for the $USER in the image building process for extra environment safety
RUN chsh -s $(which zsh)
SHELL [ "/bin/zsh", "-c" ]

#! Install ROS melodic
# remove the conflicting opencv 4.5.0 (with CUDA) pre-installed in the base image
RUN apt purge -y opencv-dev opencv-libs opencv-licenses opencv-main opencv-python opencv-scripts --autoremove

RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list' && \
    apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654 && \
    apt update -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true && \
    apt install -y ros-melodic-desktop-full && \
    echo "source /opt/ros/melodic/setup.zsh" >> ${HOME_FOLDER}/.zshrc && \
    echo "source /opt/ros/melodic/setup.bash" >> ${HOME_FOLDER}/.bashrc && \
    apt install -y python-rosdep python-rosinstall python-rosinstall-generator python-wstool && \
    rosdep init && \
    rosdep update

# Install catkin tools and rosmon
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu `lsb_release -sc` main" > /etc/apt/sources.list.d/ros-latest.list' && \
    wget http://packages.ros.org/ros.key -O - | apt-key add - && \
    apt update -o Acquire::Check-Valid-Until=false -o Acquire::AllowInsecureRepositories=true -o Acquire::AllowDowngradeToInsecureRepositories=true && \
    apt install -y python3-catkin-tools ros-melodic-rosmon

# mark-hold on libopencv-dev to 3.2
RUN apt-mark hold libopencv-dev

# install libv4l-dev, v4l-utils, and libgstreamer1.0-dev
RUN apt install -y libv4l-dev v4l-utils libgstreamer1.0-dev

#! add L4T R32.7.* apt repo, t194 is the xavier nx specific repo
RUN apt install -y gnupg && \
    apt-key adv --fetch-key https://repo.download.nvidia.com/jetson/jetson-ota-public.asc && \
    apt install -y software-properties-common && \
    add-apt-repository 'deb https://repo.download.nvidia.com/jetson/common r32.7 main' && \
    add-apt-repository 'deb https://repo.download.nvidia.com/jetson/t194 r32.7 main' && \
    apt update

# Install Bazel
ENV BAZEL_VERSION=4.2.1
RUN wget -q https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-linux-arm64 -O /usr/bin/bazel && \
    chmod a+x /usr/bin/bazel

# Install VPI 1
RUN apt install -y nvidia-vpi libnvvpi1 vpi1-dev vpi1-samples python-vpi1 python3-vpi1

# Install TensorRT
RUN apt install -y nvidia-tensorrt

# Install Ceres Solver from source
RUN apt install -y cmake libgoogle-glog-dev libgflags-dev libatlas-base-dev libeigen3-dev libsuitesparse-dev && \
    git clone --recursive https://github.com/ceres-solver/ceres-solver.git ${HOME_FOLDER}/ceres-solver -b 2.0.0 && \
    mkdir -p ${HOME_FOLDER}/ceres-solver/build && \
    cd ${HOME_FOLDER}/ceres-solver/build && \
    cmake .. && \
    make -j$(($(nproc)-1)) && \
    make install && \
    rm -rf ${HOME_FOLDER}/ceres-solver

# end of apt installs
RUN apt autoremove -y && \
    apt autoclean -y && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists/*

# Fix flann lz4 bug, https://github.com/ethz-asl/lidar_align/issues/16#issuecomment-504348488
RUN mv /usr/include/flann/ext/lz4.h /usr/include/flann/ext/lz4.h.bak && \
    mv /usr/include/flann/ext/lz4hc.h /usr/include/flann/ext/lz4.h.bak && \
    ln -s /usr/include/lz4.h /usr/include/flann/ext/lz4.h && \
    ln -s /usr/include/lz4hc.h /usr/include/flann/ext/lz4hc.h

# nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# Entrypoint command
ENTRYPOINT [ "/bin/zsh", "-c", "source ${HOME_FOLDER}/.zshrc; zsh" ]