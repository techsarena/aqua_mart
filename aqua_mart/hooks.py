app_name = "aqua_mart"
app_title = "Aqua Mart"
app_publisher = "Muhammad Saad"
app_description = "Aqua Mart is a multi-vendor marketplace for fresh water and related products."
app_email = "muhammadsaadsafdar2005@gmail.com"
app_license = "mit"

# Apps
# ------------------

# required_apps = []

# Each item in the list will be shown as an app in the apps page
# add_to_apps_screen = [
# 	{
# 		"name": "aqua_mart",
# 		"logo": "/assets/aqua_mart/logo.png",
# 		"title": "Aqua Mart",
# 		"route": "/aqua_mart",
# 		"has_permission": "aqua_mart.api.permission.has_app_permission"
# 	}
# ]

# Includes in <head>
# ------------------

# include js, css files in header of desk.html
# app_include_css = "/assets/aqua_mart/css/aqua_mart.css"
# app_include_js = "/assets/aqua_mart/js/aqua_mart.js"

# include js, css files in header of web template
# web_include_css = "/assets/aqua_mart/css/aqua_mart.css"
# web_include_js = "/assets/aqua_mart/js/aqua_mart.js"

# include custom scss in every website theme (without file extension ".scss")
# website_theme_scss = "aqua_mart/public/scss/website"

# include js, css files in header of web form
# webform_include_js = {"doctype": "public/js/doctype.js"}
# webform_include_css = {"doctype": "public/css/doctype.css"}

# include js in page
# page_js = {"page" : "public/js/file.js"}

# include js in doctype views
# doctype_js = {"doctype" : "public/js/doctype.js"}
# doctype_list_js = {"doctype" : "public/js/doctype_list.js"}
# doctype_tree_js = {"doctype" : "public/js/doctype_tree.js"}
# doctype_calendar_js = {"doctype" : "public/js/doctype_calendar.js"}

# Svg Icons
# ------------------
# include app icons in desk
# app_include_icons = "aqua_mart/public/icons.svg"

# Home Pages
# ----------

# application home page (will override Website Settings)
# home_page = "login"

# website user home page (by Role)
# role_home_page = {
# 	"Role": "home_page"
# }

# Generators
# ----------

# automatically create page for each record of this doctype
# website_generators = ["Web Page"]

# automatically load and sync documents of this doctype from downstream apps
# importable_doctypes = [doctype_1]

# Jinja
# ----------

# add methods and filters to jinja environment
# jinja = {
# 	"methods": "aqua_mart.utils.jinja_methods",
# 	"filters": "aqua_mart.utils.jinja_filters"
# }

# Installation
# ------------

# before_install = "aqua_mart.install.before_install"
# after_install = "aqua_mart.install.after_install"

# Uninstallation
# ------------

# before_uninstall = "aqua_mart.uninstall.before_uninstall"
# after_uninstall = "aqua_mart.uninstall.after_uninstall"

# Integration Setup
# ------------------
# To set up dependencies/integrations with other apps
# Name of the app being installed is passed as an argument

# before_app_install = "aqua_mart.utils.before_app_install"
# after_app_install = "aqua_mart.utils.after_app_install"

# Integration Cleanup
# -------------------
# To clean up dependencies/integrations with other apps
# Name of the app being uninstalled is passed as an argument

# before_app_uninstall = "aqua_mart.utils.before_app_uninstall"
# after_app_uninstall = "aqua_mart.utils.after_app_uninstall"

# Desk Notifications
# ------------------
# See frappe.core.notifications.get_notification_config

# notification_config = "aqua_mart.notifications.get_notification_config"

# Permissions
# -----------
# Permissions evaluated in scripted ways

# permission_query_conditions = {
# 	"Event": "frappe.desk.doctype.event.event.get_permission_query_conditions",
# }
#
# has_permission = {
# 	"Event": "frappe.desk.doctype.event.event.has_permission",
# }

# Document Events
# ---------------
# Hook on document methods and events

# doc_events = {
# 	"*": {
# 		"on_update": "method",
# 		"on_cancel": "method",
# 		"on_trash": "method"
# 	}
# }

# Scheduled Tasks
# ---------------

# scheduler_events = {
# 	"all": [
# 		"aqua_mart.tasks.all"
# 	],
# 	"daily": [
# 		"aqua_mart.tasks.daily"
# 	],
# 	"hourly": [
# 		"aqua_mart.tasks.hourly"
# 	],
# 	"weekly": [
# 		"aqua_mart.tasks.weekly"
# 	],
# 	"monthly": [
# 		"aqua_mart.tasks.monthly"
# 	],
# }

# Testing
# -------

# before_tests = "aqua_mart.install.before_tests"

# Extend DocType Class
# ------------------------------
#
# Specify custom mixins to extend the standard doctype controller.
# extend_doctype_class = {
# 	"Task": "aqua_mart.custom.task.CustomTaskMixin"
# }

# Overriding Methods
# ------------------------------
#
# override_whitelisted_methods = {
# 	"frappe.desk.doctype.event.event.get_events": "aqua_mart.event.get_events"
# }
#
# each overriding function accepts a `data` argument;
# generated from the base implementation of the doctype dashboard,
# along with any modifications made in other Frappe apps
# override_doctype_dashboards = {
# 	"Task": "aqua_mart.task.get_dashboard_data"
# }

# exempt linked doctypes from being automatically cancelled
#
# auto_cancel_exempted_doctypes = ["Auto Repeat"]

# Ignore links to specified DocTypes when deleting documents
# -----------------------------------------------------------

# ignore_links_on_delete = ["Communication", "ToDo"]

# Request Events
# ----------------
# before_request = ["aqua_mart.utils.before_request"]
# after_request = ["aqua_mart.utils.after_request"]

# Job Events
# ----------
# before_job = ["aqua_mart.utils.before_job"]
# after_job = ["aqua_mart.utils.after_job"]

# User Data Protection
# --------------------

# user_data_fields = [
# 	{
# 		"doctype": "{doctype_1}",
# 		"filter_by": "{filter_by}",
# 		"redact_fields": ["{field_1}", "{field_2}"],
# 		"partial": 1,
# 	},
# 	{
# 		"doctype": "{doctype_2}",
# 		"filter_by": "{filter_by}",
# 		"partial": 1,
# 	},
# 	{
# 		"doctype": "{doctype_3}",
# 		"strict": False,
# 	},
# 	{
# 		"doctype": "{doctype_4}"
# 	}
# ]

# Authentication and authorization
# --------------------------------

# auth_hooks = [
# 	"aqua_mart.auth.validate"
# ]

# Automatically update python controller files with type annotations for this app.
# export_python_type_annotations = True

# default_log_clearing_doctypes = {
# 	"Logging DocType Name": 30  # days to retain logs
# }

# Translation
# ------------
# List of apps whose translatable strings should be excluded from this app's translations.
# ignore_translatable_strings_from = []

# ---------------------------------------------------------------------------
# Aqua Mart API (see API_SPEC.md)
# ---------------------------------------------------------------------------

# The Flutter client calls clean REST paths under /v1 (API_SPEC 1.1), which
# are served from before_request. Order matters: the Bearer JWT is resolved
# into a session first, then the API handler answers /v1/* outright.
#
# before_request (rather than a page_renderer) because frappe/app.py routes
# only GET/HEAD/POST into the website stack, and the spec needs PATCH, PUT
# and DELETE as well. A bad token is ignored by the resolver rather than
# raising, so /auth/* never answers 401 for an expired-token reason (1.4).
before_request = [
	"aqua_mart.services.tokens.resolve_request",
	"aqua_mart.api.renderer.serve_api",
]

scheduler_events = {
	"cron": {
		# time out top-ups: pending > 5 min -> failed
		"* * * * *": ["aqua_mart.tasks.timeout_topups"],
		# expire OTPs, and roll yesterday's manual store close off
		"*/5 * * * *": [
			"aqua_mart.tasks.expire_otps",
			"aqua_mart.tasks.apply_business_hours",
		],
		# weekly payouts, Monday 06:00
		"0 6 * * 1": ["aqua_mart.tasks.build_weekly_payouts"],
	},
	"hourly": [
		"aqua_mart.tasks.escalate_stale_disputes",
		"aqua_mart.tasks.low_stock_alerts",
	],
	"daily": [
		"aqua_mart.tasks.khata_reminders",
	],
}

after_install = "aqua_mart.install.after_install"

# Fixtures ship the three app roles so a fresh site has them.
fixtures = [
	{"dt": "Role", "filters": [["name", "in", ["Aqua Customer", "Aqua Seller", "Aqua Rider"]]]},
]
