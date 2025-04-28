## Set up the Notification template

Copy the [dockcheck/notify_templates/notify_DSM.sh](https://github.com/mag37/dockcheck/blob/main/notify_templates/notify_DSM.sh) to the same directory as where you keep `dockcheck.sh`.  
Use as it (uses your default notification email setting) or edit and override manually.  

## Automate Dockcheck notifications with DSM Task Scheduler:

1. Open Control Panel and navigate to Task Scheduler
2. Create a Scheduled Task > User-defined script
3. Task Name: Dockcheck
4. User: root
5. Schedule: _User Preference_
6. Task Settings:
  1. ✔  Send run details by email (include preferred email)
  2. User-defined script: export HOME=/root && cd /path/to/dockcheck && ./dockcheck.sh -n -i -I _or other custom args_
7. Click OK, accept warning message

_Note:_ This setup will result in two emails sent, one by dockcheck (due to the -I flag) and one by DSM. The dockcheck email only includes the notification of available updates, while the DSM email shows the entire script as run. This is a user preference, and both are not necessary. Since Dockcheck cannot directly update containers in Container Manager, at least one email notification option should be enabled to use Dockcheck so you can be aware of manual updates available.


![](./dsm1.png)

![](./dsm2.png)

![](./dsm3.png)


Made with much help and contribution from [@firmlyundecided](https://github.com/firmlyundecided) and [@yoyoma2](https://github.com/yoyoma2).
