FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=UTC
ARG BLENDER_VERSION=5.2.1  # Assumes Blender 5.x.x
ARG GRASS_RELEASE=8.5.0
ARG PCL_RELEASE=1.15.1
ARG ORBBEC_SDK_VERSION=2.8.6
ARG NCORES=4

ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND} \
	TZ=${TZ} \
	LANG=C.UTF-8 \
	LC_ALL=C.UTF-8 \
	ORBBEC_SDK_DIR=/opt/OrbbecSDK_v${ORBBEC_SDK_VERSION}/lib \
	LD_LIBRARY_PATH=/opt/OrbbecSDK_v${ORBBEC_SDK_VERSION}/lib:/usr/local/lib

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Keep source trees out of the final image and make the build reproducible.
WORKDIR /tmp/tangible-landscape-build

RUN apt-get update \
	&& apt-get install -y --no-install-recommends software-properties-common ca-certificates \
	&& add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
        curl \
        cmake \
        build-essential \
		pkg-config \
		git \
		wget \
		flex \
		bison \
		gcc \
		g++ \
		ccache \
		xz-utils \
		libusb-1.0-0-dev \
		libturbojpeg0-dev \
		libsm6 \
		libice6 \
		libxext6 \
		libglfw3-dev \
		libgl1-mesa-dev \
		libglu1-mesa \
		libgtk-3-0 \
		libgtk-3-dev \
		libx11-xcb1 \
		libxkbcommon-x11-0 \
		libxrender1 \
		libcanberra-gtk3-module \
		libcanberra-gtk-module \
		fonts-dejavu \
		libboost-all-dev libeigen3-dev libflann-dev libopencv-dev \
		python3-dateutil libgsl-dev python3-numpy python3-pil python3-matplotlib \
		python3-watchdog python3-wxgtk4.0 python3-wxgtk-webview4.0 python3-pip \
		python-is-python3 libncurses-dev zlib1g-dev gettext \
		libtiff-dev libpnglite-dev libcairo2 libcairo2-dev \
		sqlite3 libsqlite3-dev libpq-dev libreadline-dev libfreetype-dev \
		libfftw3-double3 libfftw3-dev libboost-thread-dev libboost-program-options-dev \
		subversion libavutil-dev libavcodec-dev libavformat-dev libswscale-dev \
		libglu1-mesa-dev libxmu-dev ghostscript \
		libproj-dev proj-data proj-bin libgeos-dev libgdal-dev python3-gdal gdal-bin \
		libzstd-dev libpdal-dev libsdl2-dev libsvm-dev liblapacke-dev liblapack-dev \
		udev usbutils \
	&& rm -rf /var/lib/apt/lists/*

RUN curl -sL https://download.blender.org/release/Blender${BLENDER_VERSION%.*}/blender-${BLENDER_VERSION}-linux-x64.tar.xz -o blender.tar.xz \
    && tar -xf blender.tar.xz -C /opt \
    && rm blender.tar.xz \
    && ln -s /opt/blender-${BLENDER_VERSION}-linux-x64/blender /usr/local/bin/blender

RUN python3 -m pip install --break-system-packages --no-cache-dir -U \
		-f https://extras.wxpython.org/wxPython4/extras/linux/gtk3/ubuntu-24.04 wxPython

# Orbbec's package installs the SDK and its udev rules under /opt.
RUN wget -q --show-progress \
		"https://github.com/orbbec/OrbbecSDK_v2/releases/download/v${ORBBEC_SDK_VERSION}/OrbbecSDK_v${ORBBEC_SDK_VERSION}_amd64.deb" \
	&& { dpkg -i "OrbbecSDK_v${ORBBEC_SDK_VERSION}_amd64.deb" || (apt-get update && apt-get install -f -y); } \
	&& rm -f "OrbbecSDK_v${ORBBEC_SDK_VERSION}_amd64.deb" \
	&& ldconfig

RUN wget -q --show-progress \
		"https://github.com/PointCloudLibrary/pcl/archive/pcl-${PCL_RELEASE}.tar.gz" \
	&& tar -xzf "pcl-${PCL_RELEASE}.tar.gz" \
	&& cmake -S "pcl-pcl-${PCL_RELEASE}" -B pcl-build \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=/usr/local \
	&& cmake --build pcl-build --parallel ${NCORES} \
	&& cmake --install pcl-build \
	&& ldconfig \
	&& rm -rf "pcl-pcl-${PCL_RELEASE}" pcl-build "pcl-${PCL_RELEASE}.tar.gz"

RUN git clone --branch "${GRASS_RELEASE}" --depth 1 https://github.com/OSGeo/grass.git grass \
	&& cmake -S grass -B grass-build \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=/usr/local \
		-DWITH_PDAL=ON \
		-DWITH_LIBSVM=ON \
	&& cmake --build grass-build --parallel ${NCORES} \
	&& cmake --install grass-build \
	&& rm -rf grass grass-build

RUN git clone --branch femto-bolt --depth 1 https://github.com/tangible-landscape/r.in.kinect.git \
	&& OrbbecSDK_DIR="${ORBBEC_SDK_DIR}" grass --tmp-project XY --exec \
		g.extension -s extension=r.in.kinect url=/tmp/tangible-landscape-build/r.in.kinect \
	&& git clone --branch master --depth 1 https://github.com/tangible-landscape/grass-tangible-landscape.git \
	&& grass --tmp-project XY --exec \
		g.extension -s extension=g.gui.tangible url=/tmp/tangible-landscape-build/grass-tangible-landscape \
	&& rm -rf r.in.kinect grass-tangible-landscape

RUN GRASS_VERSION_SHORT="$(printf '%s' "${GRASS_RELEASE}" | cut -d. -f1,2 | tr -d .)" \
	&& printf '%s\n' \
		'[Desktop Entry]' \
		'Version=1.0' \
		'Name=GRASS' \
		'Comment=Start GRASS' \
		'Exec=/usr/local/bin/grass' \
		"Icon=/usr/local/lib/grass${GRASS_VERSION_SHORT}/share/icons/hicolor/scalable/apps/grass.svg" \
		'Terminal=true' \
		'Type=Application' \
		'Categories=GIS;Application;' \
		> /usr/share/applications/grass.desktop

WORKDIR /workspace

# Setting up the Blender environment in the container
RUN mkdir -p /workspace/Watch

CMD ["/bin/bash"]

