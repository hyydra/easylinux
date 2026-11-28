# easyset linux: generic install (any Linux), .deb and tarball
PREFIX  ?= /usr
DESTDIR ?=
VERSION := $(shell cat VERSION)
SHARE   := $(DESTDIR)$(PREFIX)/share/easyset

.PHONY: install uninstall deb tarball icons test clean

install:
	install -d $(SHARE) $(DESTDIR)$(PREFIX)/bin $(DESTDIR)/etc/easyset $(DESTDIR)/etc/xdg/autostart $(DESTDIR)/usr/share/polkit-1/actions
	cp -a install.sh VERSION README.md desktop hardware safety $(SHARE)/
	install -m 755 packaging/easyset $(DESTDIR)$(PREFIX)/bin/easyset
	ln -sf easyset $(DESTDIR)$(PREFIX)/bin/easylinux
	install -m 755 packaging/easyset-user-setup $(DESTDIR)$(PREFIX)/bin/easyset-user-setup
	sed 's|@PREFIX@|$(PREFIX)|' packaging/org.easyset.policy.in > $(DESTDIR)/usr/share/polkit-1/actions/org.easyset.policy
	chmod 644 $(DESTDIR)/usr/share/polkit-1/actions/org.easyset.policy
	sed 's|@PREFIX@|$(PREFIX)|' packaging/easyset-user.desktop > $(DESTDIR)/etc/xdg/autostart/easyset-user.desktop
	chmod 644 $(DESTDIR)/etc/xdg/autostart/easyset-user.desktop
	[ -e $(DESTDIR)/etc/easyset/easyset.conf ] || install -m 644 packaging/easyset.conf $(DESTDIR)/etc/easyset/easyset.conf
	@echo "Installed. Apply the system settings with: sudo easyset --system   (per-user ones apply at next login)"

uninstall:
	rm -rf $(SHARE)
	rm -f $(DESTDIR)$(PREFIX)/bin/easyset $(DESTDIR)$(PREFIX)/bin/easylinux $(DESTDIR)$(PREFIX)/bin/easyset-user-setup
	rm -f $(DESTDIR)/etc/xdg/autostart/easyset-user.desktop $(DESTDIR)/usr/share/polkit-1/actions/org.easyset.policy

test:
	bash tests/run.sh

deb:
	bash packaging/build-deb.sh

icons:
	bash packaging/build-icons.sh

tarball:
	mkdir -p dist
	git archive --format=tar.gz --prefix=easyset-$(VERSION)/ -o dist/easyset-$(VERSION).tar.gz HEAD

clean:
	rm -rf dist
