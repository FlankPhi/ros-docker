# Name: rosDocker
# Description: installs ROS-melodic base in ubuntu bionic environment
#
# VERSION       1.1
#

# Use the ubuntu base image
FROM ubuntu:bionic

MAINTAINER Mikal Berge, mikal@pickr.ai

# Set the inviromet to be non interative 
ENV DEBIAN_FRONTEND noninteractive

# make sure the package repository is up to date
RUN apt-get update && apt-get install -y --no-install-recommends apt-utils
RUN apt-get install -y debian-keyring debian-archive-keyring

# install ROS key
RUN apt-get install -y wget

# for TESTS of exposing port
RUN apt-get install -y netcat

# update ros repository
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu bionic main" > /etc/apt/sources.list.d/ros-latest.list'
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

RUN apt-get update

# install ROS
RUN apt-get install -y ros-melodic-ros-base

# enables you to easily download many source trees for ROS packages with one command
RUN apt-get install -y python-rosinstall

# Install additional useful packages
RUN apt-get install -y bash-completion git build-essential vim tmux

# Initialise rosdep
RUN rosdep init

# Adding vnc server
# no Upstart or DBus
# https://github.com/dotcloud/docker/issues/1724#issuecomment-26294856
RUN apt-get install -y openvpn
RUN apt-get install -y util-linux sysvinit-utils
RUN apt-mark hold util-linux sysvinit-utils udev plymouth 
RUN dpkg-divert --local --rename --add /sbin/initctl && ln -sf /bin/true /sbin/initctl

RUN apt-get install -y --force-yes --no-install-recommends supervisor \
        openssh-server pwgen sudo vim-tiny \
        net-tools \
        lxde x11vnc xvfb \
        gtk2-engines-murrine ttf-ubuntu-font-family \
        nodejs \
    && apt-get autoclean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*


ADD noVNC /noVNC
ADD supervisord.conf /


RUN cd ~ && git clone --branch 4.0.0 https://github.com/Itseez/opencv.git && \ 
    cd opencv && \
    cd ~ && git clone --branch 4.0.0 https://github.com/Itseez/opencv_contrib.git && \
    cd opencv_contrib && \
    cd ~/opencv && mkdir -p build && cd build && \
    cmake -D CMAKE_BUILD_TYPE=RELEASE \
    -D CMAKE_INSTALL_PREFIX=/usr/local \ 
    -D INSTALL_C_EXAMPLES=ON \ 
    -D INSTALL_PYTHON_EXAMPLES=ON \ 
    -D OPENCV_EXTRA_MODULES_PATH=~/opencv_contrib/modules \ 
    -D BUILD_EXAMPLES=OFF .. && \
    make -j4 && \
    make install && \ 
    ldconfig

# Launch bash when launching the container
ADD startcontainer /usr/local/bin/startcontainer
RUN chmod 755 /usr/local/bin/startcontainer

# Now create the ros user itself
RUN adduser --gecos "ROS User" --disabled-password ros
RUN usermod -a -G dialout ros

RUN mkdir /var/run/sshd

ADD 99_aptget /etc/sudoers.d/99_aptget
RUN chmod 0440 /etc/sudoers.d/99_aptget && chown root:root /etc/sudoers.d/99_aptget

RUN echo "    ForwardX11Trusted yes\n" >> /etc/ssh/ssh_config

# And, as that user...
USER ros

# HOME needs to be set explicitly. Without it, the HOME environment variable is
# set to "/"
RUN HOME=/home/ros rosdep update

# Create a ROS workspace for the ROS user.
RUN mkdir -p /home/ros/workspace/src
RUN /bin/bash -c '. /opt/ros/melodic/setup.bash; catkin_init_workspace /home/ros/workspace/src'
RUN /bin/bash -c '. /opt/ros/melodic/setup.bash; cd /home/ros/workspace; catkin_make'
ADD bashrc /.bashrc
ADD bashrc /home/ros/.bashrc

RUN mkdir -p /home/ros/Desktop
ADD xterm /home/ros/Desktop/

CMD ["/bin/bash"]
#ENTRYPOINT ["/usr/local/bin/startcontainer"]



