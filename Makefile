# easylinux: generic install (any Linux), .deb and tarball
PREFIX  ?= /usr
DESTDIR ?=
VERSION := $(shell cat VERSION)
SHARE   := $(DESTDIR)$(PREFIX)/share/easylinux

.PHONY: install uninstall deb tarball icons test clean

install:
	install -d $(SHARE) $(DESTDIR)$(PREFIX)/bin $(DESTDIR)/etc/easylinux $(DESTDIR)/etc/xdg/autostart $(DESTDIR)/usr/share/polkit-1/actions
	cp -a install.sh VERSION README.md desktop hardware safety $(SHARE)/
	install -m 755 packaging/easylinux $(DESTDIR)$(PREFIX)/bin/easylinux
	install -m 755 packaging/easylinux-user-setup $(DESTDIR)$(PREFIX)/bin/easylinux-user-setup
	sed 's|@PREFIX@|$(PREFIX)|' packaging/org.easylinux.policy.in > $(DESTDIR)/usr/share/polkit-1/actions/org.easylinux.policy
	chmod 644 $(DESTDIR)/usr/share/polkit-1/actions/org.easylinux.policy
	sed 's|@PREFIX@|$(PREFIX)|' packaging/easylinux-user.desktop > $(DESTDIR)/etc/xdg/autostart/easylinux-user.desktop
	chmod 644 $(DESTDIR)/etc/xdg/autostart/easylinux-user.desktop
	[ -e $(DESTDIR)/etc/easylinux/easylinux.conf ] || install -m 644 packaging/easylinux.conf $(DESTDIR)/etc/easylinux/easylinux.conf
	@echo "Installed. Apply the system settings with: sudo easylinux --system   (per-user ones apply at next login)"

uninstall:
	rm -rf $(SHARE)
	rm -f $(DESTDIR)$(PREFIX)/bin/easylinux $(DESTDIR)$(PREFIX)/bin/easylinux-user-setup
	rm -f $(DESTDIR)/etc/xdg/autostart/easylinux-user.desktop $(DESTDIR)/usr/share/polkit-1/actions/org.easylinux.policy

test:
	bash tests/run.sh

deb:
	bash packaging/build-deb.sh

icons:
	bash packaging/build-icons.sh

tarball:
	mkdir -p dist
	git archive --format=tar.gz --prefix=easylinux-$(VERSION)/ -o dist/easylinux-$(VERSION).tar.gz HEAD

clean:
	rm -rf dist
