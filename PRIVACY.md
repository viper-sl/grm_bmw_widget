# Privacy Policy — BMW Status (Garmin Connect IQ widget)

**Effective date:** 17 August 2026

BMW Status is a personal, non-commercial Connect IQ widget maintained at
<https://github.com/viper-sl/grm_bmw_widget>. It displays your own BMW's status on your
Garmin watch using the official [BMW CarData](https://bmw-cardata.bmwgroup.com/) API and
your own BMW account.

## The short version

**The developer of this widget receives no data from you — none, ever.** There is no
server behind this app, no account to create, no analytics, no crash reporting, no
advertising and no third-party SDK. Your vehicle data travels from BMW to your watch and
stops there.

The widget does, however, **store and transmit data that is personal to you** — your BMW
credentials and your vehicle's data, including its location. This policy explains exactly
what and where.

## What is stored on your watch

All of it lives in the app's private Connect IQ storage on the watch (and, for settings,
in Garmin Connect):

| Data | Why |
|---|---|
| Your BMW CarData **client ID** | Identifies your own BMW API client; you enter it in the widget's settings |
| OAuth **access and refresh tokens** | Keep the widget signed in to your BMW account after pairing |
| Your **VIN** and BMW **container IDs** | Discovered automatically after pairing; needed to request your vehicle's data |
| **Vehicle data** — lock state, doors, windows, range, fuel, odometer, service distance, tyre pressures, 12 V battery, coolant, and the car's **GPS position** | This is what the widget displays on its pages, glance and map |
| **Settings** — tank size, next-service override, consumption toggle, update mode | Your display preferences |

This data is not encrypted beyond the protection Garmin's platform gives app storage, and
it is only as accessible as your watch is. Anyone holding your unlocked watch can see your
vehicle's status and location in the widget, as they could in the My BMW app on an unlocked
phone.

## Where data is sent

The widget contacts exactly **two hosts**, both operated by BMW:

- `customer.bmwgroup.com` — OAuth pairing and token refresh
- `api-cardata.bmwgroup.com` — your vehicle's data

Requests are HTTPS and are relayed through the Garmin Connect Mobile app on your phone, as
all Connect IQ network traffic is. Garmin's handling of that traffic is governed by
[Garmin's privacy policy](https://www.garmin.com/privacy/); BMW's handling of your vehicle
data is governed by BMW's CarData terms and privacy notice. The widget sends your data to
no one else, and contacts no other server for any purpose.

## Permissions

- **Communications** — to make the two BMW API requests above.
- **Background** — to refresh vehicle status on a schedule while the widget is closed.

The widget does not use the watch's own GPS, does not read your activities, health or
fitness data, and does not write files to your device.

## Retention and deletion

The widget keeps data until you remove it. You are in control:

- **Settings → Manage → Sign out** deletes the stored tokens, your VIN, the container IDs
  and all cached vehicle data (including the location) from the watch.
- **Settings → Manage → Delete containers** additionally deletes the data subscriptions the
  widget created in your BMW account.
- **Uninstalling the widget** removes its storage from the watch. Your client ID setting is
  held by Garmin Connect and is cleared when you remove the app from your device there.
- You can revoke the widget's access to your vehicle at any time from the **BMW CarData
  portal**, independently of anything on the watch.

Because the developer never receives your data, there is nothing for the developer to
delete on your behalf, and no data-access request to make.

## Children

The widget is not directed at children and requires a BMW account, which BMW does not issue
to minors.

## Changes

Changes to this policy are published in this file; its history is public in the repository.
The effective date above marks the latest revision.

## Contact

Questions or concerns: open an issue at
<https://github.com/viper-sl/grm_bmw_widget/issues>.

*Not affiliated with, endorsed or supported by BMW or Garmin.*
