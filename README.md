# tangible-landscape-install
Install scripts for Tangible Landscape.

| script  | OS  | Kinect  |
|---|---|---|
| install_Ubuntu-24.04_femto-bolt.sh | Ubuntu 24.04  | Orbbec Femto Bolt |
| install_Ubuntu-24.04_k4a.sh        | Ubuntu 24.04  | Azure Kinect DK |
| install_Ubuntu-24.04_xbox-one.sh   | Ubuntu 24.04  | Kinect for Xbox One |
| install_Ubuntu-22.04_k4a.sh        | Ubuntu 22.04  | Azure Kinect DK |
| install_Ubuntu-22.04_xbox-one.sh   | Ubuntu 22.04  | Kinect for Xbox One |

## Docker image for Orbbec Femto Bolt

wxPython is the Python binding for wxWidgets, the GTK-based desktop GUI
toolkit used by GRASS and the `g.gui.tangible` plugin. It provides the windows,
menus, controls, and visualization panels; it does not communicate with the
Femto Bolt directly. Camera access is provided by the Orbbec SDK and
`r.in.kinect`.

The image installs `libgtk-3-dev` because wxPython may build from source when a
matching binary wheel is unavailable. This package provides the `gtk+-3.0`
development metadata required by `pkg-config`.

Build the Ubuntu 24.04 image:

```bash
docker build -t tangible-landscape-femto-bolt .
```

The equivalent Compose workflow is defined in `compose.yaml` and exports the
release versions into the container:

```bash
docker compose build
docker compose run --rm tangible-landscape
```

Run it with the host USB bus mounted. The USB device number can change between
runs; the device cgroup rule grants access by USB character-device class rather
than by a fixed `/dev/bus/usb/003/004` path:

```bash
docker run --rm -it \
	--mount type=bind,src=/dev/bus/usb,dst=/dev/bus/usb \
	--device-cgroup-rule='c 189:* rmw' \
	tangible-landscape-femto-bolt
```

For the GRASS GUI, also pass the host display and X11 socket:

```bash
xhost +local:docker
docker run --rm -it \
	--env DISPLAY=${DISPLAY} \
	--mount type=bind,src=/tmp/.X11-unix,dst=/tmp/.X11-unix \
	--mount type=bind,src=/dev/bus/usb,dst=/dev/bus/usb \
	--device-cgroup-rule='c 189:* rmw' \
	tangible-landscape-femto-bolt grass
```

The host must provide the USB device and the X server. Docker cannot install or
reload host udev rules, so USB permissions are supplied through the runtime
mount and cgroup rule above.

## Development Notes
* We also need to include the set-up for all the other repositories in this docker container so it always pulls the latest repo on build time. These include the Blender repo, actvities repo, and some of the directories that we need for those 

The current command to run the docker container is:
```xhost +local:docker && docker compose up```

Assuming ```echo $DISPLAY``` is set and returns something similar to ```:0```. 
