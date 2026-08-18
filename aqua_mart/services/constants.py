"""Single source of truth for every enum value the API exchanges.

Appendix A of API_SPEC.md. These strings are lowerCamelCase on purpose:
Dart's `enum.name` is used verbatim on both sides of the wire, so a casing
change here silently falls back to a default on the client rather than
raising. Never "normalise" these to snake_case.
"""

ROLE_CUSTOMER = "customer"
ROLE_SELLER = "seller"
ROLE_RIDER = "rider"
ROLES = (ROLE_CUSTOMER, ROLE_SELLER, ROLE_RIDER)

# Frappe Role records that back the three app roles.
FRAPPE_ROLE = {
	ROLE_CUSTOMER: "Aqua Customer",
	ROLE_SELLER: "Aqua Seller",
	ROLE_RIDER: "Aqua Rider",
}

GENDERS = ("female", "male", "unspecified")

# --- order status ---------------------------------------------------------
PENDING = "pending"
ACCEPTED = "accepted"
PACKED = "packed"
ON_THE_WAY = "onTheWay"
DELIVERED = "delivered"
CANCELLED_BY_CUSTOMER = "cancelledByCustomer"
REJECTED_BY_SELLER = "rejectedBySeller"

ORDER_STATUSES = (
	PENDING,
	ACCEPTED,
	PACKED,
	ON_THE_WAY,
	DELIVERED,
	CANCELLED_BY_CUSTOMER,
	REJECTED_BY_SELLER,
)

# Terminal states are final. An order never leaves one; the customer re-orders.
TERMINAL_STATUSES = (DELIVERED, CANCELLED_BY_CUSTOMER, REJECTED_BY_SELLER)

# The happy path, in order. `advance` walks this list one step at a time.
HAPPY_PATH = (PENDING, ACCEPTED, PACKED, ON_THE_WAY, DELIVERED)

# Statuses a customer is still allowed to cancel from.
CUSTOMER_CANCELLABLE = (PENDING, ACCEPTED, PACKED, ON_THE_WAY)

PAYMENT_METHODS = ("cash", "wallet", "jazzCash", "card", "khata")
PREPAID_METHODS = ("wallet", "jazzCash", "card", "khata")

LINE_KINDS = ("refill", "buyNew")
KIND_REFILL = "refill"
KIND_BUY_NEW = "buyNew"

ADDRESS_LABELS = ("home", "office", "other")

BUSINESS_TYPES = ("roPlant", "waterShop", "distributor", "mineralBrand")

DETAILS_RECEIVED = "detailsReceived"
DOCUMENTS_UPLOADED = "documentsUploaded"
IN_REVIEW = "inReview"
APPROVED = "approved"
REJECTED = "rejected"
VERIFICATION_STATUSES = (
	DETAILS_RECEIVED,
	DOCUMENTS_UPLOADED,
	IN_REVIEW,
	APPROVED,
	REJECTED,
)

RIDER_STATUSES = ("onRun", "idle", "offDuty")
STOP_STATUSES = ("pending", "delivered", "failed")
VEHICLES = ("motorbike", "rickshaw", "loader", "onFoot")

TOPUP_PROVIDERS = ("jazzCash", "easypaisa")
TOPUP_STATUSES = ("pending", "succeeded", "failed")

NOTIFICATION_KINDS = (
	"orderUpdate",
	"riderOnTheWay",
	"priceChange",
	"reorderReminder",
	"khataDue",
	"stockLow",
	"complaint",
	"payout",
	"review",
	"riderRun",
)

DISPUTE_RESOLUTIONS = ("replacement", "refund", "escalate")

# Only these three litre sizes are understood by the client; anything else
# collapses to 25L on its side, so reject unknown sizes at the edge.
BOTTLE_LITRES = (6, 10, 25)

# Deposit default (Appendix C, open question 5) - platform-wide for now.
DEFAULT_DEPOSIT = 300

# Pagination (1.8)
DEFAULT_LIMIT = 20
MAX_LIMIT = 100

# Token lifetimes (4.2)
ACCESS_TOKEN_TTL_MINUTES = 60
REFRESH_TOKEN_TTL_DAYS = 60

OTP_TTL_MINUTES = 5
OTP_MAX_ATTEMPTS = 5
OTP_RESEND_AFTER_SECONDS = 30
