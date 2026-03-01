---
title: Weekend Infrastructure - Part One
description: Let's build a simple self-hosted project that can be completed in a single weekend
date: 2026-03-20
tags:
  - weekend-infra
  - self-hosted
layout: layouts/post.njk
---

# The "Why" and "How" of Self-Hosting

## Introduction: Reclaiming Your Data

In this day and age, our data and services we utilize mostly live in the cloud, not belonging to us. Pricing can change, data can get breached, services can suddenly shut down... Unfortunately, it's pretty much impossible to be online and not rely on applications hosted outside of our control. But in certain aspects, we can keep our data to ourselves and run services on our own terms. That's where self-hosting comes to the rescue.

To put it simply, self-hosting is running various services and storing the data on hardware we have control over, be it our own physical, or rented hardware in the cloud ([Virtual Private Server - VPS](https://cloud.google.com/learn/what-is-a-virtual-private-server)).

### Self-hosting Possibilities are Endless

What can you self-host? 

Anything you developed yourself, plus billion other projects developed by other people. A nice list can be found [here](https://github.com/awesome-selfhosted/awesome-selfhosted), and [here](https://selfh.st/apps/), and [here](https://openalternative.co/self-hosted) and [here](https://selfhostlist.org/)... A very small subset of services can be found below:

- Note taking
- Bookmark manager
- Password manager
- Downloading YT videos in various formats
- File sharing
- Remote gaming
- Centralizing movie and other media 

Throughout the series, our primary focus will be on the following services:

- [NGINX Proxy Manager, or NPM](https://nginxproxymanager.com/): [Reverse proxy](https://www.youtube.com/watch?v=ozhe__GdWC8) for all of our services which will enable us to access all of them via user-defined subdomains, for example, service.ourdomain.com
- [PiHole](https://pi-hole.net/): [DNS server](https://www.cloudflare.com/learning/dns/what-is-a-dns-server/) to remove ads across our entire network and work in tandem with NGINX Proxy Manager (PiHole knows where the server is, NPM handles the routing to the specific app on that server)
- [WireGuard](https://www.wireguard.com/): [VPN server](https://vpnthat.com/2025/08/27/what-is-a-vpn-server/) to securely connect all of our devices wherever they are physically located in the world
- [Dufs](https://github.com/sigoden/dufs?tab=readme-ov-file#dufs): [File server](https://www.techtarget.com/searchnetworking/definition/file-server) which is accessible by any OS's file explorer, also accessible via browser

Once we are done with the series, you will have the knowledge to continue expanding the list and adjust everything to your own likings.  


## The "Why": Benefits of Independence

Primary benefits of self-hosting can be summarized in the following list: 

- Your data is your data only
- Your data is secure
- No ads, no tracking, more control
- No paywalls, no subscriptions
- Software is open-source
- You can run services without the fear of them getting shut down
- You like one version of the app? Stick with it forever

Other than that, you can learn a bunch of new things, primarily Linux administration, networking, containerization, orchestration and easily expand on that knowledge with various projects that suit your desires.

## The "Trade-offs": Not All is Carefree

Everything in life is a matter of weighing options and that applies here as well. Some burdens of self-hosting are the following:

- Disk goes bad and you have no redundancy ([RAID](https://www.westerndigital.com/solutions/raid)) nor backup? Good luck, you'll have to setup everything again
    - [3-2-1 backup strategy is a gold standard](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/)
- Some other component goes bad? You'll need to find replacement quick
- Regarding networking, you need to keep things tight: no default passwords, ports should not be exposed, firewall needs to be setup (VPN will significantly help us with security here)
- Cost of electricity

> Note: For readers in my home country, Bosnia and Herzegovina, small server with low power consumption CPU and 1 disk should not take more than 3-4 KM of electricity on a monthly basis

## Hardware: From Pocket-Sized to... a Little Bigger-Sized

For this series, we will utilize 3 devices:

- home server
- VPS on Hetzner
- any phone that supports WireGuard application

### VPS

First, let's talk about the VPS (Virtual Private Server). For this, we will rent a server from an EU hosting company called [Hetzner](https://www.hetzner.com/). Hetzner is an undisputed king in the budget-friendly hosting market, their offerings compared to the price is unmatched. They offer VPSs, Storage Boxes (data storage) and dedicated servers. 

In our setup, VPS's sole responsibility is to act as our VPN Gateway/server. The primary reason for hosting our VPN server on VPS, and not on the home server, is because VPS will have static public facing IP address forever. Our home server behind an IPS provided network will get different public facing IP address every time the router restarts, and that is not desirable (devices on VPN will still think VPN is on the old IP address and we will have to manually update each device in the VPN to make it work again).

By using the VPS solely as a VPN gateway, we keep our setup lean and secure. Sensitive data stays on our home server, which remains invisible to the public internet. We will bridge the two by making the home server a peer/client on the VPN in the future.

The result? Your home server won't be accessible to the outside world unless you are accessing it with a device connected to the secure VPN tunnel. And since we’re using WireGuard, you’re getting a high-performance and secure connection by default.

### Home Server

Our home server doesn't need to be anything beefy. It can be as simple as a laptop, desktop or a thin-client. Anything, as long as it has non-power hungry CPU and can take your desired workload.

To show you how simple can the home server be, I'm running a [HP T520 thin-client](https://support.hp.com/us-en/product/details/hp-t520-flexible-thin-client/6875920) with 2 GB of RAM and 128 GB SSD. TDP of the CPU is 5W, so it draws less power than a LED lightbulb. 

For this project, you can either use your every-day device, some old laptop/PC laying around, or buy a dedicated device if you decide to continue expanding on this project.

### Choice of OS

Regarding OS, we will stick with Debian on both VPS and home server. Main reasons for that are:

- Debian is rock solid by default (set-and-forget)
- it's not resource intensive
- it's 100% community driven
- it's the OS I'm most familiar with

If you are more familiar with some other Linux distro or OS, feel free to proceed with that one. 

## Be Nice To VPS, Give It a Name

For this project I highly advise you to buy some cheap domain from Cloudflare, for example, your_first_name_last_name.xyz. Why Cloudflare? They offer excellent protection against various attacks and stop the in their track, even with the free plan. The price of their domains doesn't differ too much from the competitors that don't offer any protections and their support is very good. 

Why domain name? Simply, to nicely access our services and to split them out on a sub-domain level, and not on ports. So instead of entering a.b.c.d:27015 in the browser's address bar to access some service on our server, we will use service.domainname.xyz.

## Conclusion

That's it from a clearly theoretical side. The next blog post in the series will tackle setting up the VPS on Hetzner, Wireguard and buying domain name from Cloudflare. 
