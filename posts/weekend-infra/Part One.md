---
title: Weekend Infrastructure - Part One
description: Let's build a simple self-hosted project that can be completed in a single weekend
date: 2026-03-20
tags:
  - weekend-infra
  - self-hosted
layout: layouts/post.njk
---

# The "Why" of Self-Hosting

## Reclaiming Your Data

In this day and age, our data and services we utilize mostly live in the cloud, not belonging to us. Pricing can change, data can get breached, services can suddenly shut down... Unfortunately, it's pretty much impossible to be online and not rely on some of those types of services. However, we can try as much as possible to keep at least some data to ourselves and in our control. That's where self-hosting comes to the rescue.

To put it simply, self-hosting is running various services and storing the data on hardware we have control over. Servers rented on the cloud are generally **not** considered self-hosting, but for this blog series we'll utilize them alongside our own physical server. 

## Self-hosting Possibilities are Endless

What can you self-host? 

Anything you developed yourself, plus billion other projects developed by other people. A nice list can be found [here](https://github.com/awesome-selfhosted/awesome-selfhosted), and [here](https://selfh.st/apps/), and [here](https://openalternative.co/self-hosted) and [here](https://self

## Benefits of Independence

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
    - [rsync](https://linux.die.net/man/1/rsync) is an excellent tool for backing up data
- Swap other hardware components when they break
- Regarding security, you need to keep things tight: no default passwords, ports should not be exposed, firewall needs to be setup (VPN will significantly help us with security here)
- Cost of electricity (minimal for our setup, no more than 4 BAM per month increase)

# End Goal of This Series

If you follow this series through, besides the knowledge gathered, you'll have these services at your disposal:
- [WireGuard](https://www.wireguard.com/): [VPN server](https://vpnthat.com/2025/08/27/what-is-a-vpn-server/) to securely connect to our server and other devices wherever we are in the world
- [NGINX Proxy Manager, or NPM](https://nginxproxymanager.com/): [Reverse proxy](https://www.youtube.com/watch?v=ozhe__GdWC8) which will allow us to access our hosted services by subdomain (http://service.domain.com for example), and not by using server's IP address
- [PiHole](https://pi-hole.net/): [DNS server](https://www.cloudflare.com/learning/dns/what-is-a-dns-server/) that allows removal of ads across our entire network
- [Dufs](https://github.com/sigoden/dufs?tab=readme-ov-file#dufs): [File server](https://www.techtarget.com/searchnetworking/definition/file-server) that will allow us to access our files from any device in the world

There's a ton of room for improvement here. If you like the work throughout the series, you'll have an entire playground to yourself where you can play and tinker in order to learn more and create larger and better infrastructure.

# The "How" of Self-Hosting

## Hardware: From Pocket-Sized to... a Little Bigger-Sized

For this series, we'll utilize the following hardware:

- server physically located in our home
- VPS (Virtual Private Server, server rented on the cloud)
- smartphone, any modern OS

## VPS

First, let's talk about the VPS. For this, we will rent a server from an EU hosting company called [Hetzner](https://www.hetzner.com/). Hetzner is an undisputed king in the budget-friendly hosting market, their offerings compared to the price is unmatched. They offer VPSs, Storage Boxes (data storage) and dedicated servers. 

In our setup, VPS's sole responsibility is to act as our VPN server. All of our devices will connect to it and talk to eachother via it. The primary reason for hosting our VPN server on VPS and not on the home server is because VPS will have static public facing IP address forever and it won't have any potentially vulnerable services running on it. Our home server behind an IPS provided network will get different public facing IP address every time the router restarts, which is obviously not desirable. Plus, we'll host the apps on that home server, and if some of them has a security issue, we would be in for a trouble. 

The result of this decision? Your home server won't be accessible to the outside world, unless you are accessing it with a device connected to the secure VPN tunnel. And since we’re using WireGuard, you’re getting a high-performance and secure connection by default.

## Home Server

Our home server doesn't need to be anything beefy. It can be as simple as an old laptop, desktop of any size factor (tower, SFF, USFF) or a thin-client. Anything, as long as it has non-power hungry CPU and can take your desired workload.

To show you how simple can the home server be, I'm running a [HP T520 thin-client](https://support.hp.com/us-en/product/details/hp-t520-flexible-thin-client/6875920) with 2 GB of RAM and 128 GB SSD. TDP of the CPU is 5W, so it draws less power than a LED lightbulb. 

## Choice of OS

Regarding OS, we will stick with Debian on both VPS and home server. Main reasons for that are:

- Debian is rock solid by default (set-and-forget)
- it's not resource intensive
- it's 100% community driven
- it's the OS I'm most familiar with

If you are more familiar with some other Linux distro or OS, feel free to proceed with that one. 

## Give VPS a Name

For this project I highly advise you to buy some cheap domain from Cloudflare. 

Why domain name? Simply, to nicely access our services and to split them out on a sub-domain level, and not on ports. So instead of entering 192.168.0.100:27015 in the browser's address bar to access some service on our server, we will use service.domain.xyz.

Why Cloudflare? They offer excellent protection against various attacks and stop them in their track, even with the free plan. The price of their domains doesn't differ too much from the competitors that don't offer any protections and their support is very good. 

## Conclusion

First part of this blog series primarily tackled the theoretical side of the project. The next part will focus on setting up VPS and home server. 3rd part will focus on setting up Wireguard, and 4th part will be all about running the services and making them work in proper harmony.
