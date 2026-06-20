# -*- coding: utf-8 -*-
from __future__ import print_function
import json
import os
import subprocess
import sys
import xbmc
import xbmcaddon
import xbmcgui
import xbmcplugin

ADDON = xbmcaddon.Addon()
ADDON_PATH = ADDON.getAddonInfo('path')
STORE_JSON = os.path.join(ADDON_PATH, 'resources', 'store.json')
INSTALL_BIN = '/usr/local/bin/smarttv-install-addon'


def load_store():
    with open(STORE_JSON, 'r') as fh:
        return json.load(fh)


def parse_params():
    params = {}
    if len(sys.argv) > 2:
        param_str = sys.argv[2].lstrip('?')
        for part in param_str.split('&'):
            if '=' in part:
                k, v = part.split('=', 1)
                params[k] = v
    return params


def run_install(addon_id):
    if not os.path.isfile(INSTALL_BIN):
        xbmcgui.Dialog().ok('App Store', 'Installer not found: %s' % INSTALL_BIN)
        return False
    try:
        subprocess.check_call([INSTALL_BIN, addon_id])
        return True
    except subprocess.CalledProcessError as err:
        xbmcgui.Dialog().ok('App Store', 'Install failed for %s (exit %s)' % (addon_id, err.returncode))
        return False


def main():
    handle = int(sys.argv[1])
    params = parse_params()

    if 'install' in params:
        addon_id = params['install']
        if xbmcgui.Dialog().yesno('App Store', 'Install %s?' % addon_id):
            if run_install(addon_id):
                xbmcgui.Dialog().ok('App Store', 'Installed %s. Restart Kodi if needed.' % addon_id)
        return

    store = load_store()

    if 'category' not in params:
        categories = sorted(set(item.get('category', 'Other') for item in store))
        for cat in categories:
            li = xbmcgui.ListItem(label=cat)
            xbmcplugin.addDirectoryItem(handle, 'plugin://plugin.program.smarttvstore/?category=' + cat, li, True)
        xbmcplugin.endOfDirectory(handle)
        return

    category = params['category']
    seen = set()
    for item in store:
        if item.get('category') != category:
            continue
        addon_id = item.get('id')
        if addon_id in seen:
            continue
        seen.add(addon_id)
        name = item.get('name', addon_id)
        li = xbmcgui.ListItem(label=name)
        url = 'plugin://plugin.program.smarttvstore/?install=' + addon_id
        xbmcplugin.addDirectoryItem(handle, url, li, False)
    xbmcplugin.endOfDirectory(handle)


if __name__ == '__main__':
    main()
