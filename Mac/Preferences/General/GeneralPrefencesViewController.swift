//
//  GeneralPrefencesViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/3/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore
import RSWeb
import UserNotifications

final class GeneralPreferencesViewController: NSViewController {

	private var userNotificationSettings: UNNotificationSettings?

	@IBOutlet var defaultBrowserPopup: NSPopUpButton!
    @IBOutlet weak var showUnreadCountCheckbox: NSButton!
    
	public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
		commonInit()
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		updateUI()
		updateNotificationSettings()
	}

	// MARK: - Notifications

	@objc func applicationWillBecomeActive(_ note: Notification) {
		updateUI()
	}

	// MARK: - Actions

	@IBAction func browserPopUpDidChangeValue(_ sender: Any?) {
		guard let menuItem = defaultBrowserPopup.selectedItem else {
			return
		}
		let bundleID = menuItem.representedObject as? String
		AppDefaults.shared.defaultBrowserID = bundleID
		updateUI()
	}

    
    @IBAction func toggleShowingUnreadCount(_ sender: Any) {
        guard let checkbox = sender as? NSButton else { return }

		guard userNotificationSettings != nil else {
			DispatchQueue.main.async {
				self.showUnreadCountCheckbox.setNextState()
			}
			return
		}

		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			self.updateNotificationSettings()

			if settings.authorizationStatus == .denied {
				DispatchQueue.main.async {
					self.showUnreadCountCheckbox.setNextState()
					self.showNotificationsDeniedError()
				}
			} else if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					AppDefaults.shared.hideDockUnreadCount = (checkbox.state.rawValue == 0)
				}
			} else {
				UNUserNotificationCenter.current().requestAuthorization(options: [.badge]) { (granted, error) in
					self.updateNotificationSettings()
					if granted {
						DispatchQueue.main.async {
							AppDefaults.shared.hideDockUnreadCount = checkbox.state.rawValue == 0
							NSApplication.shared.registerForRemoteNotifications()
						}
					} else {
						DispatchQueue.main.async {
							self.showUnreadCountCheckbox.setNextState()
						}
					}
				}
			}
		}
    }
}

// MARK: - Private

private extension GeneralPreferencesViewController {

	func commonInit() {
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillBecomeActive(_:)), name: NSApplication.willBecomeActiveNotification, object: nil)
	}

	func updateUI() {
		updateBrowserPopup()
        updateHideUnreadCountCheckbox()
	}

	func updateBrowserPopup() {
		let menu = defaultBrowserPopup.menu!
		let allBrowsers = MacWebBrowser.sortedBrowsers()

		menu.removeAllItems()

		let defaultBrowser = MacWebBrowser.default

		let defaultBrowserFormat = NSLocalizedString("System Default (%@)", comment: "Default browser item title format")
		let defaultBrowserTitle = String(format: defaultBrowserFormat, defaultBrowser.name!)
		let item = NSMenuItem(title: defaultBrowserTitle, action: nil, keyEquivalent: "")
		let icon = defaultBrowser.icon!
		icon.size = NSSize(width: 16.0, height: 16.0)
		item.image = icon

		menu.addItem(item)
		menu.addItem(NSMenuItem.separator())

		for browser in allBrowsers {
			let item = NSMenuItem(title: browser.name!, action: nil, keyEquivalent: "")
			item.representedObject = browser.bundleIdentifier

			let icon = browser.icon!
			icon.size = NSSize(width: 16.0, height: 16.0)
			item.image = browser.icon
			menu.addItem(item)
		}

		defaultBrowserPopup.selectItem(at: defaultBrowserPopup.indexOfItem(withRepresentedObject: AppDefaults.shared.defaultBrowserID))
	}

    func updateHideUnreadCountCheckbox() {
        showUnreadCountCheckbox.state = AppDefaults.shared.hideDockUnreadCount ? .off : .on
    }

	func updateNotificationSettings() {
		UNUserNotificationCenter.current().getNotificationSettings { (settings) in
			self.userNotificationSettings = settings
			if settings.authorizationStatus == .authorized {
				DispatchQueue.main.async {
					NSApplication.shared.registerForRemoteNotifications()
				}
			}
		}
	}

	func showNotificationsDeniedError() {
		let updateAlert = NSAlert()
		updateAlert.alertStyle = .informational
		updateAlert.messageText = NSLocalizedString("Enable Notifications", comment: "Notifications")
		updateAlert.informativeText = NSLocalizedString("To enable notifications, open Notifications in System Preferences, then find NetNewsWire in the list.", comment: "To enable notifications, open Notifications in System Preferences, then find NetNewsWire in the list.")
		updateAlert.addButton(withTitle: NSLocalizedString("Open System Preferences", comment: "Open System Preferences"))
		updateAlert.addButton(withTitle: NSLocalizedString("Close", comment: "Close"))
		let modalResponse = updateAlert.runModal()
		if modalResponse == .alertFirstButtonReturn {
			NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
		}
	}

}
