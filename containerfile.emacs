FROM quay.io/toolbx/ubuntu-toolbox:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    fish \
    ripgrep \
    fd-find \
    wl-clipboard \
    xclip \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:ubuntuhandbook1/emacs && \
    apt-get update && \
    apt-get install -y emacs-pgtk && \
    apt-get clean

COPY doom /doom
COPY emacs.d /emacs.d

#RUN ~/.emacs.d/bin/doom build


##RUN emacs --batch -f nerd-icons-install-fonts
