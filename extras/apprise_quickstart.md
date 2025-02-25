# A small guide on getting started with Apprise notifications.


## Standalone podman container: [linuxserver/apprise-api](https://hub.docker.com/r/linuxserver/apprise-api)

Set up the podman compose as preferred:
```yaml
---
version: "2.1"
services:
  apprise-api:
    image: lscr.io/linuxserver/apprise-api:latest
    container_name: apprise-api
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Etc/UTC
    volumes:
      - /path/to/apprise-api/config:/config
    ports:
      - 8000:8000
    restart: unless-stopped
```

Then browse to the webui.
![](apprise-ex1.png)
Here you'll click **Configuration Manager**, read the overview and then click on **Configuration**.
Under **Configuration** you'll craft/paste your notification config.

![](apprise-ex2.png)
The simplest way is just paste the url's as is (like in the example above).  
There are many ways to customize with tags, groups, json and more. Read [caronc/apprise-api](https://github.com/caronc/apprise-api) for more info!  

Look at the [apprise wiki: Notification Services](https://github.com/caronc/apprise/wiki) for more info about how the url syntax for different services works.  


You can also use the [caronc/apprise-api](https://github.com/caronc/apprise-api) to host the api as a frontend to an already existing **Apprise**-setup on the host.


### Customize the **notify.sh** file.
After you're done with the setup of the container and tried your notifications, you can copy the `notify_apprise.sh` file to `notify.sh` and start editing it.

Comment out/remove the bare metal apprise-command (starting with `apprise -vv -t...`).
Uncomment and edit the `AppriseURL` variable and *curl* line
It should look something like this when curling the API:
```bash
send_notification() {
Updates=("$@")
UpdToString=$( printf "%s\n" "${Updates[@]}" )
FromHost=$(hostname)

printf "\nSending Apprise notification\n"

MessageTitle="$FromHost - updates available."
# Setting the MessageBody variable here.
read -d '\n' MessageBody << __EOF
Containers on $FromHost with updates available:

$UpdToString

__EOF

AppriseURL="http://IP.or.mydomain.tld:8000/notify/apprise"
curl -X POST -F "title=$MessageTitle" -F "body=$MessageBody" -F "tags=all" $AppriseURL

}
```

That's all!
___
___


## On host installed **Apprise**
Follow the official guide on [caronc/apprise](https://github.com/caronc/apprise)!

### A brief, basic "get started"

- Install **apprise**
    - python package `pip install apprise`
    - packaged in EPEL/Fedora `dnf install apprise`
    - packaged in AUR `[yay/pikaur/paru/other] apprise`

- Create a config file with your notification credentials (source of notifications):
```ini
mailto://user:password@yahoo.com
slack://token_a/token_b/token_c
kodi://example.com
```
Then either source the notifications with `-c=/path/to/config/apprise` or store them in *PATH* to skip referencing (`~/.apprise` or `~/.config/apprise`).

- Test apprise with a single notification:
    - `apprise -vv -t 'test title' -b 'test notification body' 'mailto://myemail:mypass@gmail.com'`
- Set up your notification URL's and test them.
    - Look at the [apprise wiki: Notification Services](https://github.com/caronc/apprise/wiki) for more info about how the url syntax for different services works.  

### When done, customize the **notify.sh** file.
After you're done with the setup of the container and tried your notifications, you can copy the `notify_apprise.sh` file to `notify.sh` and start editing it.

Replace the url's corresponding to the services you've configured.
```bash
send_notification() {
Updates=("$@")
UpdToString=$( printf "%s\n" "${Updates[@]}" )
FromHost=$(hostname)

printf "\nSending Apprise notification\n"

MessageTitle="$FromHost - updates available."
# Setting the MessageBody variable here.
read -d '\n' MessageBody << __EOF
Containers on $FromHost with updates available:

$UpdToString

__EOF

# Modify to fit your setup:
apprise -vv -t "$MessageTitle" -b "$MessageBody" \
   mailto://myemail:mypass@gmail.com \
   mastodons://{token}@{host} \
   pbul://o.gn5kj6nfhv736I7jC3cj3QLRiyhgl98b \
   tgram://{bot_token}/{chat_id}/

}
```

That's all!
___
___
