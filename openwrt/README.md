# what's going on

I'm trying to configure my openwrt routers with Nix here using [nuci],
but skip the [building images] part and use the vanilla upstream one instead.

# flow

* flash-randomness: generate what's gonna be used as privkeys
* fetch-pubkeys: derive and fetch pubkeys for those privkeys into nix-confgis
* reflash or reset: plug into WAN port, bring device to square one
* bootstrap: bring device from square one to nuciable, still on WAN port
* config: actually apply the config using nuci

# devices

## jungle

GL-MT3600BE with a quirk: it needs a fix for TX,
so ethtool apk is sideloaded at bootstrap time and rc.local calls it.

[nuci]: https://github.com/lonerOrz/openwrt-nix
[building images]: https://github.com/astro/nix-openwrt-imagebuilder
