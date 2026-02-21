---
title: Blocking and non-blocking I/O
description: Showcasing blocking and non-blocking I/O
date: 2025-12-17
tags:
  - I/O
  - async
  - operating system
  - kernel
layout: layouts/post.njk
---


1st part #weekend-infra 

# The "Why" and "How" of Self-Hosting

## Introduction: Reclaiming Your Data

In this day and age, our data and services we utilize mostly live in the cloud, not belonging to us. Pricing can change, data can get breached, services can suddenly shut down... Unfortunately, it's pretty much impossible to be online and not rely on applications hosted outside of our control. But in certain aspects, we can keep our data to ourselves and run services on our own terms. That's where self-hosting comes to the rescue.

To put it simply, self-hosting is running various services and storing the data on hardware we have control over, be it our own physical, or rented hardware in the cloud (Virtual Private Server - VPS).

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
- [PiHole](https://pi-hole.net/): DNS server to remove ads across our entire network and work in tandem with NGINX Proxy Manager (PiHole tells your network where the server is, NPM handles the routing to the specific app)
- [WireGuard](https://www.wireguard.com/): VPN server to securely connect all of our devices wherever they are physically located in the world (and also make PiHole our DNS server on both local network and on VPN)
- [Dufs](https://github.com/sigoden/dufs?tab=readme-ov-file#dufs): File server which is accessible by any OS's file explorer, also accessible via browser

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

- Disk goes bad and you have no redundancy (RAID) nor backup? Good luck, you'll have to setup everything again
    - [3-2-1 backup strategy is a gold standard](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/)
- Some other component goes bad? You'll need to find replacement quick
- Regarding networking, you need to keep things tight: no default passwords, ports should not be exposed, firewall needs to be setup (VPN will significantly help us with security here)
- Cost of electricity

> Note: For readers in my home country, Bosnia and Herzegovina, small server with power saving CPU and 1 disk should not take more than 3-4 KM of electricity

## Hardware: From Pocket-Sized to... a Little Bigger-Sized

For this series, we will utilize 3 devices:

- home server
- VPS on Hetzner
- any Phone that supports WireGuard application

### VPS

First, let's talk about the VPS (Virtual Private Server). In our setup, its sole responsibility is to act as our VPN Gateway. Why not just host the VPN at home?

- The Static IP Advantage: A VPS comes with a fixed, static IP address. This is crucial for a VPN because your VPN clients (peers) need a permanent and static way to find the server
- The Home Network Problem: Most home ISPs change your public IP address every time your router restarts. Unless you pay a hefty fee for a static IP, your devices would lose the connection to your home and require a manual update every time your ISP cycles your IP

By using the VPS only as a VPN gateway, we keep our setup lean and secure. Our sensitive data stays on our home server, which remains invisible to the public internet. We will bridge the two by making the home server a peer/client on the VPN.

The result? Your home server won't be accessible to the outside world unless you are connected via our secure VPN tunnel. And since we’re using WireGuard, you’re getting a high-performance and secure connection by default.

Why Hetzner? From my experience, the quality is excellent for the very low price, servers are close and support is fantastic. I'm with them for a few years already and I don't plan to move away any time soon.

> Under the "VPS" sub-heading: Before you explain the Static IP advantage, an architectural diagram will help visual learners understand the bridge you are building. Place a diagram here: .

### Home Server

Our home server doesn't need to be anything beefy. It can be as simple as a laptop, desktop or thin-client. Anything, as long as it has low power consumption and can take your desired workload.

To show you how simple can the home server be, I'm running an old HP T520 thin-client with 2 GB of RAM and 128 GB SSD. TDP of the CPU is 5W, so it draws less power than a LED lightbulb. 

<slika t520>

But something like this is more suitable and something I would go for if I'm starting this all over again: M710q i5-7400T 2.4GHz 8GB DDR4 256GB SSD. It has more upgrade options, has more headroom out of the box, CPU is more modern with QuickSync which is a must for media streaming, more parts available since it's not a thin-client, but an actual PC... With 16 GB RAM, this system can be bought for as little as about 90 EUR, so if this project fails, you'll still have an excellent PC for home use.   

<slika m710q>

> za uporedbu, evo slika pravog servera u nekom data centru
> <slika pravog servera>

---

### Choice of OS

> The OS Transition: The jump from the Lenovo M710q hardware description straight into the Debian OS paragraph (--- Regarding OS, we will stick with Debian...) feels a bit abrupt. Give that thought its own micro-section by adding an ### Operating System heading so the reader knows you are transitioning from hardware to software.

Regarding OS, we will stick with Debian on both VPS and home server. If you are more familiar with some other distro, feel free to proceed with that one. 

## What About Domain Name

## Conclusion

That's it from a clearly theoretical side. The next blog post in the series will tackle setting up the VPS on Hetzner and WireGuard, the VPN gateway, on it. 

> dodaj vise referenci da moze raja uzeti i fino iscitati o nekim stvarima, npr za RAID i slicno
