FROM ubuntu:20.10

ARG NB_USER="jovyan"
ARG NB_UID="1000"
ARG NB_GID="100"

USER root

ENV JAVA_HOME=/usr

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND noninteractive
# Install dependencies
RUN apt-get --fix-missing update && apt-get -yq dist-upgrade
RUN apt-get install -yq --no-install-recommends \
    build-essential \
    wget \
    bzip2 \
    ca-certificates \
    sudo \
    locales \
    fonts-liberation \
    unzip \
    gnuplot \
    ghostscript \
    octave \
    liboctave-dev \
    libgdcm3.0 \
    libgdcm-dev \
    cmake \
    libnetcdf-dev \
    libopencv-dev \
    git \
    net-tools \
    fonts-freefont-ttf \
    fonts-freefont-otf \
    openjdk-15-jdk-headless \
    mysql-server \
    nodejs \
    npm \
    graphviz \
    texlive-xetex \
    texlive-latex-recommended \
    texlive-latex-extra \
    texlive-fonts-recommended \
    r-base \
    r-recommended \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen

# Configure environment
ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=$NB_USER \
    NB_UID=$NB_UID \
    NB_GID=$NB_GID \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER

ADD fix-permissions /usr/local/bin/fix-permissions
RUN chmod +x /usr/local/bin/fix-permissions
# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo $NB_UID
RUN echo $CONDA_DIR

RUN groupadd wheel -g 11 && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd && \
    fix-permissions $HOME && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /opt

USER $NB_UID
RUN mkdir /home/$NB_USER/tmp

# Setup work directory for backward-compatibility
RUN mkdir /home/$NB_USER/work

USER root
RUN fix-permissions /home/$NB_USER

# Install conda as jovyan and check the md5 sum provided on the download site
ENV MINICONDA_VERSION 4.9.2
RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-py38_${MINICONDA_VERSION}-Linux-x86_64.sh && \
    echo "122c8c9beb51e124ab32a0fa6426c656 *Miniconda3-py38_${MINICONDA_VERSION}-Linux-x86_64.sh" | md5sum -c - && \
    /bin/bash Miniconda3-py38_${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-py38_${MINICONDA_VERSION}-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda install --quiet --yes conda="${MINICONDA_VERSION%.*}.*" && \
    $CONDA_DIR/bin/conda update --all --quiet --yes && \
    conda clean -tipsy && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install Jupyter Notebook, Lab, and Hub
# Generate a notebook server config
# Cleanup temporary files
# Correct permissions
# Do all this in a single RUN command to avoid duplicating all of the
# files across image layers when the permissions change
RUN conda install --quiet --yes \
    'notebook' \
    'jupyterhub' \
    'jupyterlab' && \
    conda clean -tipsy && \
    jupyter labextension install @jupyterlab/hub-extension && \
    npm cache clean --force && \
    jupyter notebook --generate-config && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache/yarn && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

USER root

RUN octave --eval "pkg install -forge control"
RUN octave --eval "pkg install -forge struct"
RUN octave --eval "pkg install -forge io"
RUN octave --eval "pkg install -forge statistics"
RUN octave --eval "pkg install -forge dicom"
RUN octave --eval "pkg install -forge image"
RUN octave --eval "pkg install -forge linear-algebra"
RUN octave --eval "pkg install -forge lssa"
RUN octave --eval "pkg install -forge optics"
RUN octave --eval "pkg install -forge optim"
RUN octave --eval "pkg install -forge optiminterp"
RUN octave --eval "pkg install -forge quaternion"
RUN octave --eval "pkg install -forge queueing"
RUN octave --eval "pkg install -forge signal"
RUN octave --eval "pkg install -forge sockets"
RUN octave --eval "pkg install -forge splines"
RUN octave --eval "pkg install -forge netcdf"
RUN octave --eval "pkg install -forge symbolic"

# Install Octave kernel
RUN conda config --add channels conda-forge
RUN conda install octave_kernel

# Download and extract IJava kernel from SpencerPark
RUN cd /tmp && \
    wget https://github.com/SpencerPark/IJava/releases/download/v1.3.0/ijava-1.3.0.zip && \
    unzip ijava-1.3.0.zip && \
    python install.py --sys-prefix

# R kernel
RUN conda install -c r r-irkernel

# C++ kernel
# https://blog.jupyter.org/interactive-workflows-for-c-with-jupyter-fe9b54227d92
RUN conda install xeus-cling -c conda-forge

# slideshows
RUN conda install -c conda-forge rise

# SOS kernel
RUN pip install pip --upgrade
RUN pip install xlrd docker
RUN pip install markdown wand graphviz imageio pillow
RUN conda install -y feather-format -c conda-forge
RUN pip install nbformat --upgrade
## trigger rerun for sos updates
ARG	DUMMY=unknown
RUN DUMMY=${DUMMY} pip install sos sos-notebook sos-r sos-julia sos-python sos-matlab sos-javascript sos-bash sos-bioinfo --upgrade
RUN python -m sos_notebook.install

USER $NB_UID

# MySQL kernel
RUN pip install git+https://github.com/shemic/jupyter-mysql-kernel --user

# python module required to access mysql
RUN pip install pandas

# javascript kernel
RUN npm install -g ijavascript
RUN ijsinstall

# Bash kernel
RUN pip install bash_kernel
RUN python -m bash_kernel.install

# Markdown kernel
RUN pip install markdown-kernel
RUN python -m markdown_kernel.install

USER root
# nbextensions
RUN conda install -c conda-forge jupyter_contrib_nbextensions
RUN jupyter nbextension enable execute_time/ExecuteTime
RUN jupyter nbextension enable rubberband/main
RUN jupyter nbextension enable exercise2/main
RUN jupyter nbextension enable freeze/main
RUN jupyter nbextension enable hide_input/main
RUN jupyter nbextension enable init_cell/main
RUN jupyter nbextension enable scratchpad/main
RUN jupyter nbextension enable init_cell/main
RUN jupyter nbextension enable scroll_down/main
RUN jupyter nbextension enable toc2/main
RUN jupyter nbextension enable collapsible_headings/main
RUN jupyter nbextension enable collapsible_headings/main
RUN jupyter nbextension enable gist_it/main

#nbgrader
RUN conda install -c conda-forge nbgrader

#save as pdf bugfix
RUN apt-get update && apt-get -yq dist-upgrade
RUN apt-get install -yq --no-install-recommends texlive

#drawing inside jupyter notebook
RUN pip install git+https://github.com/uclmr/egal.git
RUN jupyter nbextension install --py egal
RUN jupyter nbextension enable --py egal

#visualization toolkit
RUN conda install bokeh

#dicom
RUN conda install -c conda-forge pydicom

#volume visualization
RUN conda install -c conda-forge ipyvolume

#kotlin kernel
RUN conda install -c jetbrains kotlin-jupyter-kernel

#k3d for 3d visualization
RUN pip install k3d

#fix problem cannot connect to kernel with container running on windows
#see https://github.com/jupyter/notebook/issues/2664
RUN pip uninstall -y tornado
RUN pip install tornado==5.1.1

# Download and extract Processing
RUN cd /tmp && \
    wget http://download.processing.org/processing-3.5.4-linux64.tgz && \
    tar zxvf processing-3.5.4-linux64.tgz -C /usr/local/

#required for jupyter server
RUN pip install tornado --upgrade

RUN jupyter labextension install transient-display-data
RUN jupyter labextension install jupyterlab-sos
RUN jupyter labextension install jupyterlab-drawio
RUN jupyter labextension install jupyterlab_iframe
RUN pip install ipycanvas
RUN jupyter labextension install ipycanvas

# RUN apt-get install -yq postgresql postgresql-contrib
RUN conda install -y -c conda-forge ipython-sql
RUN conda install -y -c conda-forge postgresql
RUN conda install -y -c anaconda psycopg2
RUN conda install -y -c conda-forge pgspecial

USER $NB_UID

# processing kernel
RUN	pip install --upgrade calysto_processing --user && \
	python3 -m calysto_processing install --user

#display maps via python
RUN pip install folium

# Remove unused folders
RUN rm -r /home/$NB_USER/tmp
RUN rm -r /home/$NB_USER/work

EXPOSE 3306
EXPOSE 8888

WORKDIR $HOME

user root

ADD my.cnf /etc/mysql/my.cnf
RUN chown $NB_USER:$NB_UID /etc/mysql/my.cnf
RUN mkdir -p /var/run/mysqld
RUN mkdir -p /usr/local/mysql/var
RUN chown -R $NB_USER:$NB_UID /var/lib/mysql
RUN chown -R $NB_USER:$NB_UID /var/log/mysql
RUN chown -R $NB_USER:$NB_UID /var/run/mysqld
RUN chown -R $NB_USER:$NB_UID /usr/local/mysql
# required in order to make mysqld work in docker container
VOLUME /usr/local/mysql/var

# build all remaining jupyter extensions
RUN jupyter lab build

# Add local files as late as possible to avoid cache busting

USER root
RUN mkdir -p /home/$NB_USER/.local/config/
ADD mysql_config.json /home/$NB_USER/.local/config/mysql_config.json
RUN chmod +r /home/$NB_USER/.local/config/mysql_config.json
ADD imshow.m /usr/share/octave/5.2.0/m/image/
RUN chmod +r /usr/share/octave/5.2.0/m/image/imshow.m
ADD jupyter_notebook_config.py /etc/jupyter/
RUN fix-permissions /etc/jupyter/
ADD start.sh /usr/local/bin/
RUN chmod +rx /usr/local/bin/start.sh
ADD start-notebook.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start-notebook.sh
ADD mysql-init /home/jovyan/
RUN chmod +r /home/jovyan/mysql-init

user $NB_UID

# Install Tini
RUN conda install --quiet --yes 'tini=0.18.0' && \
    conda list tini | grep tini | tr -s ' ' | cut -d ' ' -f 1,2 >> $CONDA_DIR/conda-meta/pinned && \
    conda clean -tipsy && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# START
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/local/bin/start-notebook.sh"]
