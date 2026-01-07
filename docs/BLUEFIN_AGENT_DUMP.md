# IMPORTANT: 
**NOTE:** This is a dump from my conversation with a BLUEFIN AI agent. One of the extraction prompts I shared towards the end requested things like HEX codes and branding details--this was a mistake and these unrelated details should be sanitized from the report you will create. 

I will include my message and the agent's response below for full historical context:

---

    I am trying to build a custom image using BlueBuild based on Silverblue, but on Fedora Asahi Remix, on my M1 Macbook Pro. I already have Silverblue running on this machine, bare metal (no UTM/VM needed). I watched Jorge Castro's recent talk and read up about plans for Bluefin for 2026 and understand that Jorge believes that instead of building a distro this is essentially just a bunch of Docker containers (i'm heavily paraphrasing--I don't have as firm a grasp on the inner-workings of this 'cloud native' stuff yet). What I'm asking is, do I still need BlueBuild (or similar) to build my image, or is there now a better way, based specifically on what Bluefin is doing as of today, Jan 2, 2026

You don't need BlueBuild anymore for custom Bluefin (or Silverblue-derived) images. As of early 2026, Bluefin has fully shifted to a cloud native, container-based workflow. The recommended way to build or customize images is to use the [image-template repo](https://github.com/ublue-os/image-template) and the unified Justfile build system. You can clone the template, tweak your Containerfile or configuration, and run justfile commands like `just build bluefin stable` to build your image locally or in CI/CD—no legacy image-building tools required. The build process uses Podman under the hood and is designed to work on any infrastructure, including ARM/Apple Silicon hardware running Fedora Asahi Remix or similar distros. This approach aligns with Jorge Castro's "just a bunch of containers" vision and lets you layer, extend, or strip down Bluefin as you see fit, with most apps delivered as Flatpaks or containers rather than traditional RPMs.

For Apple Silicon or T2 Macs, if you need extra firmware (like wifi/bluetooth), you’ll want to include it in your custom image via a Containerfile layer or script, or rebase to a community image like [T2-Atomic](https://github.com/lauretano/t2-atomic) that already includes the necessary bits. Rebasing and layering are the main workflows now, not traditional image builds. More details and step-by-step instructions are in the [official Bluefin docs](https://docs.projectbluefin.io/local) and [custom image tips](https://docs.projectbluefin.io/tips) [1](https://docs.projectbluefin.io/local) [2](https://docs.projectbluefin.io/tips) [3](https://docs.projectbluefin.io/t2-mac).

If you want to get started, check out:
- [Bluefin local build docs](https://docs.projectbluefin.io/local)
- [Image template repo](https://github.com/ublue-os/image-template)
- [Tips for custom Bluefin images](https://docs.projectbluefin.io/tips)
- [T2 Mac/Apple Silicon specifics](https://docs.projectbluefin.io/t2-mac)

Let me know if you want a quick example Containerfile or justfile command for your use case!

---

    I want to keep digging here to better understand. I will share my findings with Gemini 3 Pro with "whom" I have been building my custom image repo. I see Jorge mentioned in his latest video that there is a 'distroless' version of Bluefin on the horizon, and seemingly already in development/testing. Is this more or less what you're referring to when you say a BlueBuild (or uBuild) process i no longer needed? Can you give me a basic playbook of how I would go about building this newer kind of image that does not require a BlueBuild process? BlueBuild has been difficult to work with in some ways and eliminating a process like this could be a game changer. Essentially and from what I understand, I need to pull in the Asahi kernel (which may or may not now be merged into the Fedora kernel--more research needed here) and ALL Asahi-specific tools/drivers/configs/packages, into my custom image. Up to this point I've been trying to modify Silverblue (https://quay.io/organization/fedora-asahi-remix-atomic-desktops) to essentially be a sort of Asahi/Bluefin kind of thing. If I could start with an existing Bluefin image and bake in the Asahi stuff, that might be a better approach. Please weigh in and share as much detail as possible. Get as technical and specific as you can; I will be feeding this plan into my AI agent. NOTE: I am NOT asking about or interested in T2 Mac support at this time; my ONLY aim for this project currently is bare metal Apple Silicon support. As I said, I know it's possible because I am running Silverblue on my Macbook Pro M1 Pro with great success. I installed Fedora Asahi Remix per Asahi's instructions and then performed a 'takeover' to install Silverblue in place of the standard "workstation" build that Fedora Asahi Remix is build on.

Yes, the "distroless" Bluefin image (sometimes called `bluefin-gnome`) is the prototype for the new, container-native workflow that replaces BlueBuild/uBuild. The modern approach is to use a container-based build system (Containerfile + Justfile + Podman), not legacy image builders. This is how Bluefin, and the broader Universal Blue ecosystem, now expects you to build, customize, and distribute images—including for ARM/Apple Silicon targets and Asahi integration. The distroless image is still evolving, but the core workflow is already in production for all Bluefin images and is what you should use going forward [1](https://github.com/projectbluefin/distroless/blob/b800bada80d1ab2668ed6b24915a98468bd72266/README.md#L10-L32) [2](https://docs.projectbluefin.io/local) [3](https://docs.projectbluefin.io/tips).

**How to build a custom Bluefin+Asahi image (no BlueBuild):**

1. **Start with the [image-template repo](https://github.com/ublue-os/image-template):**  
   - Click "Use this template" to create your own repo.
   - Clone it locally.

2. **Pick your base image:**  
   - In `Containerfile`, set `FROM ghcr.io/ublue-os/bluefin:stable` (or another Bluefin tag).
   - For ARM/Apple Silicon, make sure you’re building for `aarch64` and that your base image supports it. If you want to start from an Asahi base, you could use a Fedora Asahi Remix Atomic Desktop image, but Bluefin LTS ARM is the most mature Universal Blue ARM image right now [4](https://docs.projectbluefin.io/blog/page/2).

3. **Add Asahi kernel and tools:**  
   - In `build_files/build.sh`, add the logic to install the Asahi kernel, firmware, and any Asahi-specific packages, drivers, or configs. If these are not in Fedora mainline, you’ll need to pull them from the Asahi repos (see [Fedora Asahi Remix Atomic Desktops](https://github.com/fedora-asahi-remix-atomic-desktops/images) for inspiration).
   - Example (in `build.sh`):
     ```bash
     # Example: Add Asahi kernel repo and install kernel/asahi tools
     rpm-ostree install --idempotent \
       https://asahi.fedoraproject.org/aarch64/kernel-asahi.rpm \
       asahi-firmware asahi-bless asahi-config
     ```
     (Replace with actual package names/URLs as needed.)

4. **Customize further as needed:**  
   - Add any other packages, configs, or scripts to `build.sh`.
   - You can also copy in files, set up system extensions, or tweak GNOME/Bluefin settings.

5. **Build your image:**  
   - Run `just build $image_name $tag` (e.g., `just build my-bluefin-asahi latest`). This uses Podman to build the container image.
   - For multiarch (e.g., ARM + x86), use Podman’s `--platform` and `--manifest` options [5](https://app.dosu.dev/documents/2625da74-392d-43d8-aebd-d43c7b025b13).

6. **Sign your image:**  
   - Generate a cosign key and add it to your repo’s GitHub secrets for CI builds (see the template README for details).

7. **Build a bootable ISO (optional):**  
   - Use [titanoboa](https://github.com/ublue-os/titanoboa) or the Justfile’s `build-iso` command to generate an installer ISO from your OCI image [6](https://app.dosu.dev/documents/ca90e59a-7c14-44c5-860e-0919ef6d54d0).

8. **Deploy:**  
   - On your target system, run `sudo bootc switch ghcr.io/<your-org>/<your-image>:latest` to rebase to your new image.

**Why this is better:**  
- No BlueBuild/uBuild, no legacy tooling—just container-native, reproducible builds.
- You can layer, rebase, or fork images as needed, and everything is managed in code (Containerfile, build.sh, Justfile).
- This is the same workflow used for all Universal Blue images, including Bluefin LTS ARM and the new distroless/bluefin-gnome prototypes.

**References and examples:**  
- [image-template repo (recommended starting point)](https://github.com/ublue-os/image-template)
- [Bluefin local build docs](https://docs.projectbluefin.io/local)
- [Distroless Bluefin repo (for advanced/minimal builds)](https://github.com/projectbluefin/distroless)
- [Fedora Asahi Remix Atomic Desktops (for Asahi-specific bits)](https://github.com/fedora-asahi-remix-atomic-desktops/images)
- [Titanoboa ISO builder](https://github.com/ublue-os/titanoboa)

If you want a concrete example Containerfile or build.sh for Asahi, let me know which kernel/tools you want and I can sketch it out. This workflow is what Jorge and the Universal Blue team are pushing for all new custom images [7](https://docs.projectbluefin.io/introduction#distroless-focus) [8](https://github.com/projectbluefin/distroless/blob/b800bada80d1ab2668ed6b24915a98468bd72266/Containerfile#L1-L26).

---

    Yes, I want a concrete Containerfile and build.sh example specifically for Asahi. I'm going to share some links that you may or may not find helpful--take what you need and leave the rest:

    https://github.com/AsahiLinux/m1n1
    https://github.com/AsahiLinux/linux
    https://github.com/AsahiLinux/u-boot
    https://github.com/AsahiLinux/muvm
    https://github.com/AsahiLinux/asahi-audio
    https://github.com/AsahiLinux/asahi-installer
    https://github.com/AsahiLinux/tuxvdmtool
    https://github.com/AsahiLinux/asahi-scripts
    https://github.com/AsahiLinux/asahi-nvram
    https://github.com/AsahiLinux/asahi-plymouth
    https://github.com/AsahiLinux/speakersafetyd

Here’s a concrete starting point for a Bluefin/Asahi custom image using the modern container-native workflow. This approach uses the [image-template repo](https://github.com/ublue-os/image-template) and is compatible with ARM64/Apple Silicon. You’ll need to adapt package URLs and names to match the latest Asahi kernel, firmware, and tools (see [AsahiLinux repos](https://github.com/AsahiLinux/linux), [m1n1](https://github.com/AsahiLinux/m1n1), etc.).

**Containerfile example:**
```Dockerfile
FROM ghcr.io/ublue-os/bluefin:stable

# For ARM64/Apple Silicon, ensure you build for aarch64
# Add Asahi kernel repo (replace with actual repo URL if needed)
RUN curl -o /etc/yum.repos.d/asahi.repo https://asahi.fedoraproject.org/aarch64/asahi.repo

# Remove default kernel, install Asahi kernel and firmware
RUN dnf remove -y kernel* \
    && dnf install -y kernel-asahi asahi-firmware asahi-bless asahi-config \
    && dnf clean all

# Optional: Add m1n1, u-boot, audio, and other tools if available as RPMs
RUN dnf install -y m1n1 u-boot asahi-audio speakersafetyd asahi-nvram

# Optional: Add Plymouth theme for Asahi
RUN dnf install -y plymouth
COPY asahi-plymouth /usr/share/plymouth/themes/asahi
RUN plymouth-set-default-theme -R asahi
```

**build.sh example:**
```bash
#!/usr/bin/env bash
set -euo pipefail

# If you need to build m1n1, u-boot, or other tools from source:
# git clone https://github.com/AsahiLinux/m1n1.git
# cd m1n1 && make

# Regenerate initramfs after kernel swap
dracut --force --regenerate-all

# Set up any required firmware, configs, or system extensions
# Example: Copy custom DSP configs for asahi-audio
cp -r /path/to/asahi-audio/configs /etc/asahi-audio/

# Optional: Set up NVRAM tool
cp /path/to/asahi-nvram /usr/local/bin/

# Clean up build artifacts if needed
```

**Caveats and tips:**
- If Asahi kernel/tools aren’t available as RPMs, you’ll need to build them from source in build.sh and copy binaries into the image.
- For m1n1 and u-boot, follow their repo instructions for cross-compiling on ARM64 and include the resulting binaries.
- Regenerating initramfs after kernel swap is critical for bootability.
- For audio, include speakersafetyd and PipeWire configs as described in [asahi-audio](https://github.com/AsahiLinux/asahi-audio).
- For Plymouth, copy the theme and set it as default as shown above.
- Use [titanoboa](https://github.com/ublue-os/titanoboa) or the Justfile’s `build-iso` to create a bootable installer ISO if needed.

This workflow is what the Universal Blue/Bluefin team recommends for all new custom images, including ARM64/Apple Silicon targets. You can layer, rebase, and extend as needed, and everything is managed in code ([reference](https://github.com/ublue-os/image-template), [discussion](https://github.com/ublue-os/bluefin/issues/2051)). 

Let me know if you want more detail on building any specific Asahi component from source or integrating a particular hardware enablement feature.

---

    PROTOCOL: TOTAL RECALL (DEEP EXTRACTION)
    Context: We are archiving this session state to a persistent Knowledge Base. I require a complete, lossless dump of all critical data, decisions, and creative assets generated in this thread.
    Your Role: Archivist & Data Miner.
    THE DIRECTIVE:
    Do not summarize. Do not "yada yada." If a list has 20 items, list all 20. If a code snippet was 50 lines, provide all 50.
    DATA TO EXTRACT:
    The Hard Assets:
    All specific names, titles, and codenames discussed (Accepted AND Rejected).
    All Hex codes, color palettes, and visual style definitions.
    All specific copy/text written for UI, READMEs, or Scripts.
    The Logic:
    Why did we make specific decisions? (The "Why").
    What constraints did we identify?
    The "Unknowns":
    Scan your context window for details I may have forgotten to ask about. If it seems relevant to the project's future, dump it here.
    OUTPUT FORMAT:
    Use Markdown code blocks for raw data.
    Use clear headers.
    Loop Clause: If you hit a token limit or cut off, stop exactly where you are. Do not try to rush the ending. I will type "CONTINUE" to get the rest.
    Begin.

# TOTAL RECALL: DEEP EXTRACTION

---

## THE HARD ASSETS

### Specific Names, Titles, and Codenames (Accepted AND Rejected)

```markdown
- Bluefin
- Bluefin LTS
- Bluefin GTS
- Bluefin LTS ARM
- Bluefin-gnome (distroless Bluefin)
- Universal Blue
- uBlue
- uBlue OS
- uBlue main
- BlueBuild
- uBuild
- Silverblue
- Fedora Asahi Remix
- Fedora Asahi Remix Atomic Desktops
- Asahi Linux
- Asahi kernel
- m1n1
- u-boot
- muvm
- asahi-audio
- asahi-installer
- tuxvdmtool
- asahi-scripts
- asahi-nvram
- asahi-plymouth
- speakersafetyd
- T2-Atomic
- titanoboa
- bootc
- bootc-image-builder
- Podman
- Justfile
- Containerfile
- build.sh
- build_files/build.sh
- build.yml
- build-disk.yml
- disk_config/iso.toml
- disk_config/iso-gnome.toml
- disk_config/iso-kde.toml
- disk_config/disk.toml
- cosign
- artifacthub.io
- m2Giles' OS
- bOS
- Homer
- Amy OS
- VeneOS
- boxkit
- bluefin-cli
- Brewfile
- quadlets
- distrobox
- toolbox
- aurora-dx
- bazzite
- bazzite-arch
- bluefin-nvidia
- silverblue-main
- ghcr.io/ublue-os/bluefin:stable
- ghcr.io/ublue-os/bazzite:stable
- ghcr.io/ublue-os/silverblue-main:42
- quay.io/fedora-ostree-desktops/silverblue:41
- quay.io/fedora/fedora-bootc:41
- quay.io/centos-bootc/centos-bootc:stream10
- ghcr.io/ublue-os/aurora-dx:latest
- github.com/ublue-os/image-template
- github.com/projectbluefin/distroless
- github.com/ublue-os/bluefin
- github.com/ublue-os/bluefin-lts
- github.com/ublue-os/packages
- github.com/ublue-os/toolboxes
- github.com/ublue-os/boxkit
- github.com/ublue-os/titanoboa
- github.com/ublue-os/devcontainer
- github.com/ublue-os/universal-blue-org
- github.com/ublue-os/akmods
- github.com/ublue-os/homebrew-tap
- github.com/ublue-os/common
- github.com/ublue-os/main
- github.com/ublue-os/toolboxes
- github.com/ublue-os/image-template
- github.com/fedora-asahi-remix-atomic-desktops/images
- https://quay.io/organization/fedora-asahi-remix-atomic-desktops
```

---

### Hex Codes, Color Palettes, and Visual Style Definitions

```markdown
- Bluefin color palette and visual style assets are referenced in the official blog:
  - [Color with Bluefin blog post](https://docs.projectbluefin.io/blog/color-with-bluefin)
  - [Downloadable PDF with color palette](https://download.projectbluefin.io/color-with-bluefin.pdf)
  - [Discussion about color palette](https://docs.projectbluefin.io/blog/color-with-bluefin#discussion)
- Actual hex codes and palette details are in the PDF, not directly in this session.
```

---

### Specific Copy/Text Written for UI, READMEs, or Scripts

#### Containerfile Example (from session)

```Dockerfile
FROM ghcr.io/ublue-os/bluefin:stable

# For ARM64/Apple Silicon, ensure you build for aarch64
# Add Asahi kernel repo (replace with actual repo URL if needed)
RUN curl -o /etc/yum.repos.d/asahi.repo https://asahi.fedoraproject.org/aarch64/asahi.repo

# Remove default kernel, install Asahi kernel and firmware
RUN dnf remove -y kernel* \
    && dnf install -y kernel-asahi asahi-firmware asahi-bless asahi-config \
    && dnf clean all

# Optional: Add m1n1, u-boot, audio, and other tools if available as RPMs
RUN dnf install -y m1n1 u-boot asahi-audio speakersafetyd asahi-nvram

# Optional: Add Plymouth theme for Asahi
RUN dnf install -y plymouth
COPY asahi-plymouth /usr/share/plymouth/themes/asahi
RUN plymouth-set-default-theme -R asahi
```

#### build.sh Example (from session)

```bash
#!/usr/bin/env bash
set -euo pipefail

# If you need to build m1n1, u-boot, or other tools from source:
# git clone https://github.com/AsahiLinux/m1n1.git
# cd m1n1 && make

# Regenerate initramfs after kernel swap
dracut --force --regenerate-all

# Set up any required firmware, configs, or system extensions
# Example: Copy custom DSP configs for asahi-audio
cp -r /path/to/asahi-audio/configs /etc/asahi-audio/

# Optional: Set up NVRAM tool
cp /path/to/asahi-nvram /usr/local/bin/

# Clean up build artifacts if needed
```

#### Example Dockerfile for Kernel Swap (from support thread)

```Dockerfile
FROM quay.io/fedora-ostree-desktops/silverblue:41

RUN dnf5 config-manager addrepo --from-repofile=https://pkg.surfacelinux.com/fedora/linux-surface.repo
RUN dnf5 -y remove kernel* && \
    rm -r /root # not necessary on ublue-os/main derived images
RUN dnf5 -y install --allowerasing kernel-surface iptsd libwacom-surface
```
[Source](https://github.com/ublue-os/bluefin/issues/2051)

#### image-template Containerfile (from repo)

```Dockerfile
# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

FROM ghcr.io/ublue-os/bazzite:stable

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
```
[Source](https://github.com/ublue-os/image-template/blob/9d2b6e562e46a62620f05cc79aa05178cdf80618/Containerfile#L1-L40)

#### image-template build.sh (from repo)

```bash
set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux 

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
```
[Source](https://github.com/ublue-os/image-template/blob/9d2b6e562e46a62620f05cc79aa05178cdf80618/build_files/build.sh#L3-L25)

#### disk_config/iso-gnome.toml (from repo)

```toml
%post
bootc switch --mutate-in-place --transport registry ghcr.io/ublue-os/image-template:latest
%end

[customizations.installer.modules]
enable = [
  "org.fedoraproject.Anaconda.Modules.Storage",
  "org.fedoraproject.Anaconda.Modules.Runtime"
]
disable = [
  "org.fedoraproject.Anaconda.Modules.Network",
  "org.fedoraproject.Anaconda.Modules.Security",
  "org.fedoraproject.Anaconda.Modules.Services",
  "org.fedoraproject.Anaconda.Modules.Users",
  "org.fedoraproject.Anaconda.Modules.Subscription",
  "org.fedoraproject.Anaconda.Modules.Timezone"
]
```
[Source](https://github.com/ublue-os/image-template/blob/9d2b6e562e46a62620f05cc79aa05178cdf80618/disk_config/iso-gnome.toml#L3-L20)

#### disk_config/iso-kde.toml (from repo)

```toml
%post
bootc switch --mutate-in-place --transport registry ghcr.io/ublue-os/image-template:latest
%end

[customizations.installer.modules]
enable = [
  "org.fedoraproject.Anaconda.Modules.Storage",
  "org.fedoraproject.Anaconda.Modules.Runtime",
  "org.fedoraproject.Anaconda.Modules.Network",
  "org.fedoraproject.Anaconda.Modules.Security",
  "org.fedoraproject.Anaconda.Modules.Services",
  "org.fedoraproject.Anaconda.Modules.Users",
  "org.fedoraproject.Anaconda.Modules.Timezone"
]
disable = [
  "org.fedoraproject.Anaconda.Modules.Subscription",
]
```
[Source](https://github.com/ublue-os/image-template/blob/9d2b6e562e46a62620f05cc79aa05178cdf80618/disk_config/iso-kde.toml#L3-L21)

---

## THE LOGIC (WHY)

```markdown
- The Bluefin project and Universal Blue ecosystem have moved away from legacy image-building tools like BlueBuild/uBuild in favor of a container-native, reproducible workflow using Podman, Containerfile, and Justfile. This approach is more maintainable, portable, and aligns with modern cloud-native practices [source](https://github.com/ublue-os/bluefin/issues/2051).
- The distroless Bluefin image (bluefin-gnome) is the prototype for this new workflow, which is now the standard for all Universal Blue images, including ARM/Apple Silicon targets [source](https://github.com/projectbluefin/distroless).
- The image-template repository is the canonical starting point for building custom images, supporting kernel swaps, hardware enablement, and all customizations in code [source](https://github.com/ublue-os/image-template/blob/9d2b6e562e46a62620f05cc79aa05178cdf80618/README.md#L3-L264).
- Kernel swapping is now done via dnf in the Containerfile, not rpm-ostree replace, for better compatibility and reproducibility [source](https://github.com/ublue-os/bluefin/issues/2051).
- Regenerating initramfs after kernel swap is critical for bootability, but must be handled carefully due to ostree constraints [source](https://github.com/ublue-os/bluefin/issues/2051).
- The build.sh script is the best place to install packages, enable systemd units, and make other system customizations [source](https://github.com/ublue-os/image-template/blob/9d2b6e562e46a62620f05cc79aa05178cdf80618/build_files/build.sh#L3-L25).
- The disk_config TOML files provide ready-to-edit configurations for QCOW2/ISO builds and show how to set kickstarts that switch to the final OCI image on install [source](https://github.com/ublue-os/image-template/blob/9d2b6e562e46a62620f05cc79aa05178cdf80618/disk_config/iso-gnome.toml#L3-L20).
- Community images and examples (m2Giles' OS, bOS, Homer, Amy OS, VeneOS) demonstrate the flexibility and adoption of this workflow [source](https://github.com/ublue-os/image-template/blob/9d2b6e562e46a62620f05cc79aa05178cdf80618/README.md#L3-L264).
```

---

## CONSTRAINTS

```markdown
- Asahi kernel and tools may not be available as RPMs; if so, they must be built from source in build.sh and binaries copied into the image.
- Kernel swapping with dnf works but requires careful handling of initramfs regeneration; dracut and rpm-ostree commands may fail due to ostree constraints.
- If the base image does not include RPM Fusion repos, build.sh must manually add them to install certain packages [source](https://github.com/ublue-os/image-template/issues/108#issuecomment-2906425111).
- When building a qcow2 image using bootc-image-builder with the silverblue-main image, GDM/GNOME may fail to start after reboot due to /var and /etc being mounted read-only, caused by an obsolete fstab entry. Using silverblue-main:42 as the base image prevents this [source](https://github.com/ublue-os/image-template/issues/72).
- The user is not interested in T2 Mac support; only bare metal Apple Silicon support is in scope.
- Regenerating initramfs after kernel swap is critical for bootability.
- The default build.sh assumes RPM Fusion repos are present, but this depends on the base image.
```

---

## THE UNKNOWNS

```markdown
- Are there additional color palettes, hex codes, or visual style definitions in the referenced PDF or discussion that should be extracted for future branding or theming?
- Are there rejected names, titles, or codenames that were considered but not accepted, beyond those explicitly listed?
- What is the current status of Asahi kernel/tool RPM availability for Fedora/Bluefin images?
- Are there workflow gaps or missing assets for full Asahi/Bluefin integration not covered in the current documentation?
- Are there any additional constraints or logic decisions implied but not directly stated in the session?
- Are there hard assets (scripts, config files, etc.) referenced but not fully included in the session that should be extracted if available?
```

---

    PROTOCOL: TOTAL RECALL (UNIVERSAL)
    Context: We are archiving this session state to a persistent Knowledge Base. I require a complete, lossless dump of all critical data, decisions, and artifacts generated in this thread.

    Your Role: Lead Archivist & Data Miner.

    THE DIRECTIVE:
    Do not summarize. Do not "yada yada." Do not interpret.

    If a list has 20 items, list all 20.
    If a concept has 5 specific constraints, list all 5.
    If specific text/code/data was generated, provide the raw content.
    DATA TO EXTRACT:

    The Entities & Artifacts (The "What"):

    List ALL specific names, titles, terminology, and identifiers created or discussed (Accepted AND Rejected).
    Extract ALL raw values (Data points, configuration settings, specific definitions, or verbatim text blocks previously generated).
    Catalog ALL output artifacts (Code snippets, drafts, outlines, or structural hierarchies).
    The Logic & Strategy (The "Why"):

    What specific decisions were finalized?
    What options were rejected, and why?
    What specific constraints, rules, or guidelines were established?
    The "Unknown Unknowns" (The Context):

    Scan your context window for details I may have forgotten to ask about.
    Identify any "Latent Risks," "Future To-Dos," or "Unresolved Open Loops."
    If there are philosophical or stylistic alignments defined, list them.
    OUTPUT FORMAT:

    Use Markdown Code Blocks for raw data/text to preserve exact formatting.
    Use clear, hierarchical headers.
    Loop Clause: If you hit a token limit or cut off, STOP exactly where you are. Do not try to rush the ending or compress data to fit. I will type "CONTINUE" to get the rest.
    Begin the extraction.

```markdown
# 🛑 PROTOCOL: TOTAL RECALL (UNIVERSAL)

---

## 1. The Entities & Artifacts (The "What")

### All Specific Names, Titles, Terminology, and Identifiers (Accepted AND Rejected)

- Bluefin
- Bluefin LTS
- Bluefin GTS
- Bluefin LTS ARM
- Bluefin-gnome
- distroless Bluefin
- Universal Blue
- uBlue
- uBlue OS
- uBlue main
- BlueBuild
- uBuild
- Silverblue
- Fedora Asahi Remix
- Fedora Asahi Remix Atomic Desktops
- Asahi Linux
- Asahi kernel
- m1n1
- u-boot
- muvm
- asahi-audio
- asahi-installer
- tuxvdmtool
- asahi-scripts
- asahi-nvram
- asahi-plymouth
- speakersafetyd
- T2-Atomic
- titanoboa
- bootc
- bootc-image-builder
- Podman
- Justfile
- Containerfile
- build.sh
- build_files/build.sh
- build.yml
- build-disk.yml
- disk_config/iso.toml
- disk_config/iso-gnome.toml
- disk_config/iso-kde.toml
- disk_config/disk.toml
- cosign
- artifacthub.io
- m2Giles' OS
- bOS
- Homer
- Amy OS
- VeneOS
- boxkit
- bluefin-cli
- Brewfile
- quadlets
- distrobox
- toolbox
- aurora-dx
- bazzite
- bazzite-arch
- bluefin-nvidia
- silverblue-main
- ghcr.io/ublue-os/bluefin:stable
- ghcr.io/ublue-os/bazzite:stable
- ghcr.io/ublue-os/silverblue-main:42
- quay.io/fedora-ostree-desktops/silverblue:41
- quay.io/fedora/fedora-bootc:41
- quay.io/centos-bootc/centos-bootc:stream10
- ghcr.io/ublue-os/aurora-dx:latest
- github.com/ublue-os/image-template
- github.com/projectbluefin/distroless
- github.com/ublue-os/bluefin
- github.com/ublue-os/bluefin-lts
- github.com/ublue-os/packages
- github.com/ublue-os/toolboxes
- github.com/ublue-os/boxkit
- github.com/ublue-os/titanoboa
- github.com/ublue-os/devcontainer
- github.com/ublue-os/universal-blue-org
- github.com/ublue-os/akmods
- github.com/ublue-os/homebrew-tap
- github.com/ublue-os/common
- github.com/ublue-os/main
- github.com/ublue-os/toolboxes
- github.com/ublue-os/image-template
- github.com/fedora-asahi-remix-atomic-desktops/images
- https://quay.io/organization/fedora-asahi-remix-atomic-desktops

---

### All Raw Values (Data Points, Configuration Settings, Specific Definitions, Verbatim Text Blocks)

#### Containerfile Example

```Dockerfile
FROM ghcr.io/ublue-os/bluefin:stable

# For ARM64/Apple Silicon, ensure you build for aarch64
# Add Asahi kernel repo (replace with actual repo URL if needed)
RUN curl -o /etc/yum.repos.d/asahi.repo https://asahi.fedoraproject.org/aarch64/asahi.repo

# Remove default kernel, install Asahi kernel and firmware
RUN dnf remove -y kernel* \
    && dnf install -y kernel-asahi asahi-firmware asahi-bless asahi-config \
    && dnf clean all

# Optional: Add m1n1, u-boot, audio, and other tools if available as RPMs
RUN dnf install -y m1n1 u-boot asahi-audio speakersafetyd asahi-nvram

# Optional: Add Plymouth theme for Asahi
RUN dnf install -y plymouth
COPY asahi-plymouth /usr/share/plymouth/themes/asahi
RUN plymouth-set-default-theme -R asahi
```

#### build.sh Example

```bash
#!/usr/bin/env bash
set -euo pipefail

# If you need to build m1n1, u-boot, or other tools from source:
# git clone https://github.com/AsahiLinux/m1n1.git
# cd m1n1 && make

# Regenerate initramfs after kernel swap
dracut --force --regenerate-all

# Set up any required firmware, configs, or system extensions
# Example: Copy custom DSP configs for asahi-audio
cp -r /path/to/asahi-audio/configs /etc/asahi-audio/

# Optional: Set up NVRAM tool
cp /path/to/asahi-nvram /usr/local/bin/

# Clean up build artifacts if needed
```

#### image-template Containerfile

```Dockerfile
# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

FROM ghcr.io/ublue-os/bazzite:stable

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
```

#### image-template build.sh

```bash
set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux 

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
```

#### disk_config/iso-gnome.toml

```toml
%post
bootc switch --mutate-in-place --transport registry ghcr.io/ublue-os/image-template:latest
%end

[customizations.installer.modules]
enable = [
  "org.fedoraproject.Anaconda.Modules.Storage",
  "org.fedoraproject.Anaconda.Modules.Runtime"
]
disable = [
  "org.fedoraproject.Anaconda.Modules.Network",
  "org.fedoraproject.Anaconda.Modules.Security",
  "org.fedoraproject.Anaconda.Modules.Services",
  "org.fedoraproject.Anaconda.Modules.Users",
  "org.fedoraproject.Anaconda.Modules.Subscription",
  "org.fedoraproject.Anaconda.Modules.Timezone"
]
```

#### disk_config/iso-kde.toml

```toml
%post
bootc switch --mutate-in-place --transport registry ghcr.io/ublue-os/image-template:latest
%end

[customizations.installer.modules]
enable = [
  "org.fedoraproject.Anaconda.Modules.Storage",
  "org.fedoraproject.Anaconda.Modules.Runtime",
  "org.fedoraproject.Anaconda.Modules.Network",
  "org.fedoraproject.Anaconda.Modules.Security",
  "org.fedoraproject.Anaconda.Modules.Services",
  "org.fedoraproject.Anaconda.Modules.Users",
  "org.fedoraproject.Anaconda.Modules.Timezone"
]
disable = [
  "org.fedoraproject.Anaconda.Modules.Subscription",
]
```

---

## 2. The Logic & Strategy (The "Why")

- The project moved away from legacy image-building tools (BlueBuild/uBuild) to a container-native, reproducible workflow using Podman, Containerfile, and Justfile for maintainability, portability, and alignment with modern cloud-native practices.
- The distroless Bluefin image (bluefin-gnome) is the prototype for this new workflow, now standard for all Universal Blue images, including ARM/Apple Silicon targets.
- The image-template repository is the canonical starting point for building custom images, supporting kernel swaps, hardware enablement, and all customizations in code.
- Kernel swapping is now done via dnf in the Containerfile, not rpm-ostree replace, for better compatibility and reproducibility.
- Regenerating initramfs after kernel swap is critical for bootability, but must be handled carefully due to ostree constraints.
- The build.sh script is the best place to install packages, enable systemd units, and make other system customizations.
- The disk_config TOML files provide ready-to-edit configurations for QCOW2/ISO builds and show how to set kickstarts that switch to the final OCI image on install.
- Community images and examples (m2Giles' OS, bOS, Homer, Amy OS, VeneOS) demonstrate the flexibility and adoption of this workflow.

---

## 3. The "Unknown Unknowns" (The Context)

- Are there additional color palettes, hex codes, or visual style definitions in the referenced PDF or discussion that should be extracted for future branding or theming?
- Are there rejected names, titles, or codenames that were considered but not accepted, beyond those explicitly listed?
- What is the current status of Asahi kernel/tool RPM availability for Fedora/Bluefin images?
- Are there workflow gaps or missing assets for full Asahi/Bluefin integration not covered in the current documentation?
- Are there any additional constraints or logic decisions implied but not directly stated in the session?
- Are there hard assets (scripts, config files, etc.) referenced but not fully included in the session that should be extracted if available?

---
```

---

    Eric
    2 hours ago
    Give me a complete report on the following for the Bluefin project (this assumes ALL user types, especially any DX, AI/ML, and Creative roles:

    all cli tools and packages along with descriptions / use case
    all flatpaks along with descriptions / use case
    all custom GNOME config options along with descriptions / use case
    any GNOME extensions along with descriptions / use case
    all custom Plymouth details (boot screen)
    anything with uBoot an image builder/designer/maintainer would need to know (if applicable)
    Also:

    explain in detail the initial user setup flow (after the user account is created for the OS/installer process)
    explain how ujust works in this system and all its Bluefin-specific commands
    explain how the new builds handle Grub, or whether that is no longer part of the image (Jorge briefly mentioned this but I didn't understand it)
    explain the benefits of the new Bluefin and uBlue build processes, migration towards more containers than packages/package managers

Here’s a comprehensive breakdown for Bluefin, covering all user types (DX, AI/ML, Creative):

---

### CLI Tools & Packages

Bluefin is container- and Flatpak-first, but ships a robust CLI/tooling stack for devs, AI/ML, and creative users. Key tools include:

- **Homebrew**: The primary CLI package manager, integrated via an OCI image. Use it for installing dev tools, fonts, and utilities. [Details](https://docs.projectbluefin.io/blog/tags/announcements#homebrew)
- **Podman & Podman Desktop**: Default container runtime and GUI for managing containers and Kubernetes workflows. [Details](https://docs.projectbluefin.io/bluefin-dx#podman-and-podman-desktop)
- **Docker**: Included for compatibility with devcontainers and cloud-native workflows.
- **Incus**: System container runtime (not in LTS).
- **Devpod**: For managing devcontainers.
- **bcc, bpftrace, iproute2, nicstat, numactl, sysprof, sysstat, tiptop, trace-cmd, util-linux**: Performance and profiling tools.
- **fzf, fish, zsh**: Shell and CLI productivity.
- **kcli**: CLI for managing VMs.
- **rclone, restic**: Backup utilities.
- **python3-boto3, python3-pydantic-core, ImageMagick, LibRaw**: Useful for AI/ML and creative workflows.
- **bcc, bpftrace**: For advanced system tracing (DX/AI/ML).
- **bcc, bpftrace, sysstat, tiptop, trace-cmd**: System profiling (DX/AI/ML).
- **bcache-tools, ddcutil**: Storage and monitor management.
- **ZFS, akmods, kernel-tools**: Advanced storage and kernel module management (LTS/HWE).

See [changelog](https://docs.projectbluefin.io/changelogs/page/6) for a full package list.

---

### Flatpaks

Bluefin is Flatpak-first for all graphical apps. Key Flatpaks (preinstalled or recommended):

- **Bazaar**: The default Flatpak app store, replacing GNOME Software. [Details](https://docs.projectbluefin.io/blog/tags/announcements#introducing-bazaar)
- **VS Code**: Default IDE, with devcontainer support.
- **Pinta, Thunderbird**: Added for creative/productivity use.
- **Deja Dup, Pika Backup**: Backup utilities.
- **Embellish**: Font management.
- **DistroShelf**: GUI for managing pet containers.
- **Devtoolbox, Devpod**: Developer tools.
- **Input Leap, Simple Scan**: For device and scanning support.
- **JetBrains Toolbox**: Install via `ujust jetbrains-toolbox` for JetBrains IDEs (recommended over Flatpak versions).
- **Creative/AI/ML**: Use Flatpak for GIMP, Inkscape, Blender, Krita, etc. via Flathub.

Flatpaks are managed system-wide, not per-user. [Details](https://docs.projectbluefin.io/blog/tags/announcements#flatpak-tracker)

---

### Custom GNOME Config & Extensions

- **Custom GNOME Config**: Bluefin applies curated GNOME settings for a clean, productive desktop. Branding and schema packages (`bluefin-backgrounds`, `bluefin-logos`, `bluefin-schemas`) provide custom theming and layout. [Details](https://docs.projectbluefin.io/changelogs/page/6)
- **Extensions**:
  - **Logo Menu**: Adds a branded menu.
  - **Search Light**: Enhanced search experience.
  - **AppIndicator**: System tray support.
  - **Blur My Shell**: Visual polish.
  - **GSConnect**: Integrates with KDE Connect for device sync.
  - [See full list](https://docs.projectbluefin.io/changelogs/page/6)

---

### Plymouth (Boot Screen)

Bluefin uses custom branding for Plymouth (boot splash), with updated backgrounds and logos via the `bluefin-backgrounds` and `bluefin-logos` packages. This ensures a consistent, branded boot experience. [Details](https://docs.projectbluefin.io/changelogs/page/6)

---

### uBoot

No evidence that uBoot is used or relevant for Bluefin image building or deployment. Bluefin targets UEFI systems only. [Details](https://docs.projectbluefin.io/installation)

---

### Initial User Setup Flow

1. **Install OS**: Use Anaconda web UI or Readymade installer (Live CD experience). Both include all Flatpaks and required software.
2. **First Boot**: Standard GNOME initial setup runs (language, keyboard, online accounts).
3. **Secure Boot**: Prompt to enroll Universal Blue key (or run `ujust enroll-secure-boot-key`).
4. **User Config**: Install apps via Bazaar, CLI tools via Homebrew, sync dotfiles (e.g., with chezmoi).
5. **Backups**: Set up Deja Dup/Pika Backup or CLI tools.
6. **Developer Mode**: Enable with `ujust devmode`, then `ujust dx-group` and reboot for full DX features.
7. **Maintenance**: Use `ujust update`, `ujust changelogs`, `ujust bios`, `ujust clean-system` for system management.
[Details](https://docs.projectbluefin.io/installation)

---

### ujust: Task Runner & Bluefin-Specific Commands

- **ujust** is a task runner (based on just/ublue-os-just) for automation and system tasks.
- Key Bluefin-specific commands:
  - `ujust bluefin-ai`: Installs AI/ML tools.
  - `ujust bluefin-k8s`: Installs Kubernetes admin tools (cdk8s, k0sctl, k3sup, kind, dagger, grype, helm, kubectl, k9s, kubectx, pack, syft).
  - `ujust bluefin-fonts`: Installs curated monospace fonts.
  - `ujust devmode`: Enables developer mode.
  - `ujust dx-group`: Adds user to dev groups.
  - `ujust jetbrains-toolbox`: Installs JetBrains Toolbox.
  - `ujust rebase-helper`: Switches kernel streams (e.g., HWE).
  - `ujust update`, `ujust changelogs`, `ujust bios`, `ujust clean-system`: System maintenance.
  - `ujust enroll-secure-boot-key`: Enrolls Secure Boot key.
- The Justfile also supports local image builds, ISO creation, SBOM generation, and container signature verification for advanced users/image builders.
[Details](https://docs.projectbluefin.io/blog/tags/announcements#ujust-commands-returning)

---

### Grub Handling in New Builds

Bluefin is moving away from legacy bootloader setups. Some Grub-related packages (like `grubby`) are being removed, and the build process is modernized to focus on container-based images and UEFI boot. Boot management is handled via `bootc` and container signatures, not traditional Grub configs. [Details](https://docs.projectbluefin.io/changelogs/page/6)

---

### Benefits of New Build Process & Container Migration

- **Centralized, automated builds**: Shared codebase with Aurora/Bazzite, less legacy code, fewer bugs.
- **Container-first**: All graphical apps are Flatpaks; CLI/dev tools via Homebrew or containers.
- **Cloud-native**: Uses `bootc`, Podman, Docker, Incus, Devpod for system and dev workflows.
- **Reproducibility & Security**: Images are signed, SBOMs generated, and system cleanup is automated.
- **User separation**: OS and dev environment are decoupled—dev tools live in containers or user space.
- **DX/AI/ML/Creative**: Out-of-the-box support for modern workflows, with curated tools and easy onboarding.
- **Maintenance**: Near-zero touch for users; updates, backups, and system tasks are streamlined.
[Details](https://docs.projectbluefin.io/blog/bluefin-f42)

---

If you need a specific, up-to-date package or Flatpak list, or want more detail on a particular workflow (e.g., AI/ML, creative, DX), let me know!

---

# NOTE: I also pulled the latest Bluefin down and will output the ENTIRE `tree` here:

```
.
├── AGENTS.md
├── artifacthub-repo.yml
├── build_files
│   ├── base
│   │   ├── 00-image-info.sh
│   │   ├── 03-install-kernel-akmods.sh
│   │   ├── 04-packages.sh
│   │   ├── 05-override-install.sh
│   │   ├── 08-firmware.sh
│   │   ├── 17-cleanup.sh
│   │   ├── 18-workarounds.sh
│   │   ├── 19-initramfs.sh
│   │   └── 20-tests.sh
│   ├── dx
│   │   ├── 00-dx.sh
│   │   └── 01-tests-dx.sh
│   └── shared
│       ├── build-dx.sh
│       ├── build-gnome-extensions.sh
│       ├── build.sh
│       ├── clean-stage.sh
│       ├── copr-helpers.sh
│       ├── utils
│       │   └── ghcurl
│       └── validate-repos.sh
├── Containerfile
├── CONTRIBUTING.md
├── cosign.pub
├── flatpaks
│   ├── system-flatpaks-dx.list
│   ├── system-flatpaks-extra.list
│   └── system-flatpaks.list
├── image-versions.yml
├── iso_files
│   ├── bluefin.repo
│   ├── configure_iso_anaconda.sh
│   ├── configure_lts_iso_anaconda.sh
│   └── README.md
├── Justfile
├── LICENSE
├── README.md
└── system_files
    ├── dx
    │   ├── etc
    │   │   └── skel
    │   └── usr
    │       ├── bin
    │       │   └── bluefin-dx-groups
    │       ├── lib
    │       │   ├── dracut
    │       │   │   └── dracut.conf.d
    │       │   │       └── 80-vfio.conf
    │       │   ├── sysctl.d
    │       │   │   └── docker-ce.conf
    │       │   ├── systemd
    │       │   │   └── system
    │       │   │       ├── bluefin-dx-groups.service
    │       │   │       ├── incus-workaround.service
    │       │   │       ├── libvirt-workaround.service
    │       │   │       └── swtpm-workaround.service
    │       │   └── tmpfiles.d
    │       │       ├── incus-workaround.conf
    │       │       ├── libvirt-workaround.conf
    │       │       └── swtpm-workaround.conf
    │       └── share
    │           └── ublue-os
    │               └── user-setup.hooks.d
    │                   └── 10-vscode.sh
    └── shared
        ├── etc
        │   ├── environment
        │   ├── rpm-ostreed.conf
        │   ├── systemd
        │   │   └── user.conf
        │   ├── ublue-os
        │   │   ├── bling.json
        │   │   └── setup.json
        │   └── zsh
        │       ├── zlogin
        │       ├── zlogout
        │       ├── zprofile
        │       ├── zshenv
        │       └── zshrc
        └── usr
            ├── lib
            │   ├── bootc
            │   │   └── install
            │   │       └── 20-bluefin.toml
            │   ├── dracut
            │   │   └── dracut.conf.d
            │   │       ├── 10-compression.conf
            │   │       └── 90-ublue.conf
            │   ├── sysctl.d
            │   │   └── 80-inotify.conf
            │   ├── systemd
            │   │   ├── system
            │   │   │   ├── dconf-update.service
            │   │   │   ├── flatpak-nuke-fedora.service
            │   │   │   ├── flatpak-preinstall.service
            │   │   │   ├── ublue-fix-hostname.service
            │   │   │   └── ublue-guest-user.service
            │   │   └── user
            │   │       └── bazaar.service
            │   └── tmpfiles.d
            │       ├── bazaar-flatpak.conf
            │       └── pmcd.conf
            └── share
                ├── color
                │   └── icc
                │       └── colord
                │           ├── framework13.icc
                │           └── framework16.icc
                ├── fish
                │   └── vendor_functions.d
                │       └── fish_prompt.fish
                ├── flatpak
                │   └── preinstall.d
                │       └── bazaar.preinstall
                ├── gnome-shell
                │   └── extensions
                │       ├── appindicatorsupport@rgcjonas.gmail.com
                │       ├── blur-my-shell@aunetx
                │       ├── dash-to-dock@micxgx.gmail.com
                │       ├── gsconnect@andyholmes.github.io
                │       ├── logomenu@aryan_k
                │       ├── search-light@icedman.github.com
                │       └── tmp
                │           └── caffeine
                └── ublue-os
                    ├── firefox-config
                    │   └── 01-bluefin-global.js
                    ├── flatpak-overrides
                    │   └── io.github.kolunmi.Bazaar
                    ├── motd
                    │   ├── template.md
                    │   └── tips
                    │       └── 10-tips.md
                    ├── privileged-setup.hooks.d
                    │   ├── 10-tailscale.sh
                    │   └── 99-flatpaks.sh
                    ├── system-setup.hooks.d
                    │   └── 10-framework.sh
                    └── user-setup.hooks.d
                        ├── 10-theming.sh
                        ├── 20-framework.sh
                        └── 99-privileged.sh

66 directories, 81 files
```