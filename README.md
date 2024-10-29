![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=for-the-badge&logo=docker&logoColor=white)
![Alpine Linux](https://img.shields.io/badge/Alpine_Linux-%230D597F.svg?style=for-the-badge&logo=alpine-linux&logoColor=white)

# Alpine Linux Handheld Daemon Docker Container

This container includes both
[Handheld Daemon](https://github.com/hhd-dev/hhd) and [Handheld Daemon UI](https://github.com/hhd-dev/hhd-ui)

Port `5335` is used for Handheld Daemon. By default, it will listen to 127.0.0.1:5335 inside the container and cannot be trivially exposed to the host. This container uses socat to expose the service at port `5336`, which in turn can be mapped to the docker host port `5335`. For `hhd-ui` port `17000` is used.

## Building

```sh
docker build -t hhd .
```

## Running

Before running the container make sure udev rules are set correctly on the host.

Instructions to set the appropriate udev rules for hhd are derived from hhd-dev/hhd [readme.md](https://github.com/hhd-dev/hhd/blob/9d7bf94c9cc5c07f076305f23a7dbe6ef4dd68dc/readme.md?plain=1#L351-L355).

According to HHD's readme.md file, the udev rules needs to be installed from the `master` branch, means it can be changed at any point. Instead, we can take the udev rules from a specific commit:

```sh
# save udev rules from hhd-dev/hhd
sudo curl https://raw.githubusercontent.com/hhd-dev/hhd/9d7bf94c9cc5c07f076305f23a7dbe6ef4dd68dc/usr/lib/udev/rules.d/83-hhd-user.rules -o /etc/udev/rules.d/83-hhd-user.rules
sudo curl https://raw.githubusercontent.com/hhd-dev/hhd/9d7bf94c9cc5c07f076305f23a7dbe6ef4dd68dc/usr/lib/modules-load.d/hhd-user.conf -o /etc/modules-load.d/hhd-user.conf

# reload udev rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Installing `acpi_call` module in the host is required in order to set TDP values for some devices, such as the Lenovo Legion Go.

**Please note the following:**

You need to set `UID` and `GID` according to your user ID and group.

`--privileged` is being used to access and create devices. This setting is very permissive, if you can figure how to run this container without setting this, please let me know.

`--restart=unless-stopped` will keep the container running across reboots. Remove this argument to revert this.

Once the container is running, using the UI is as simple as accessing `http://localhost:17000` with a web browser.

Authentication token is needed to access settings. Token can be read from `token` file created at the `config` folder. This file is being created once HHD is up and running.

Finally, run the container:

```sh
docker run \
    -e UID=$(id -u) \
    -e GID=$(id -g) \
    -v $HOME/.config/hhd/:/home/hhd/.config/hhd/ \
    -v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket \
    -p 127.0.0.1:5335:5336 \
    -p 127.0.0.1:17000:17000 \
    --privileged \
    --restart=unless-stopped \
    -d \
    --name hhd \
    hhd
```

Once launched you can check the process logs:

```sh
docker logs -f hhd
```
