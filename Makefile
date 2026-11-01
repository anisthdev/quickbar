# Installs quickbar as a system Quickshell config, run with `qs -c quickbar`.
#
#   /usr/share/quickbar                 the shell (QML, icons, data, scripts)
#   /etc/xdg/quickshell/quickbar        → /usr/share/quickbar, where qs -c looks
#   /usr/lib/quickbar/                  the scripts run from outside the shell
#   /usr/bin/quickbar-download          the downloads runner, for any app
#                                       (docs/downloads.md)
#   quickbar.service                    the shell as a systemd user service,
#                                       restarted (and locked) after a crash
#   systemd user unit, D-Bus activation and .portal for the file chooser
#
# A ~/.config/quickshell/quickbar of your own (a link to a checkout, say)
# comes first, so `qs -c quickbar` runs that instead while you work on it.
#
# PREFIX is /usr only: portal/quickbar-portal.service names /usr/lib/quickbar.

PREFIX  ?= /usr
DESTDIR ?=

SHARE := $(DESTDIR)$(PREFIX)/share/quickbar
LIB   := $(DESTDIR)$(PREFIX)/lib/quickbar
SHELL_FILES := $(wildcard *.qml) components modules icons data scripts pam
# Run by Hyprland, hypridle, xdph, systemd and Claude Code
ENTRY_POINTS := boot share-picker filechooser-portal claude-usage

.PHONY: install
install:
	install -d $(SHARE)
	cp -r --no-preserve=ownership $(SHELL_FILES) $(SHARE)/
	find $(SHARE) -name __pycache__ -prune -exec rm -rf {} +
	install -d $(DESTDIR)/etc/xdg/quickshell
	ln -sfn $(PREFIX)/share/quickbar $(DESTDIR)/etc/xdg/quickshell/quickbar
	install -d $(LIB)
	for s in $(ENTRY_POINTS); do ln -sfn ../../share/quickbar/scripts/$$s $(LIB)/$$s; done
	install -d $(DESTDIR)$(PREFIX)/bin
	ln -sfn ../share/quickbar/scripts/download $(DESTDIR)$(PREFIX)/bin/quickbar-download
	install -Dm644 systemd/quickbar.service \
		$(DESTDIR)$(PREFIX)/lib/systemd/user/quickbar.service
	install -Dm644 portal/quickbar-portal.service \
		$(DESTDIR)$(PREFIX)/lib/systemd/user/quickbar-portal.service
	install -Dm644 portal/org.freedesktop.impl.portal.desktop.quickbar.service \
		$(DESTDIR)$(PREFIX)/share/dbus-1/services/org.freedesktop.impl.portal.desktop.quickbar.service
	install -Dm644 portal/quickbar.portal \
		$(DESTDIR)$(PREFIX)/share/xdg-desktop-portal/portals/quickbar.portal
	install -Dm644 -t $(DESTDIR)$(PREFIX)/share/doc/quickbar docs/*.md
