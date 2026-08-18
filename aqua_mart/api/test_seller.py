from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch

from aqua_mart.api.seller import _cnic_validation_errors, _multipart_text


class TestSellerCnicValidation(TestCase):
	front = """
	Islamic Republic of Pakistan
	National Identity Card
	Name Muhammad Saad
	Father Name Muhammad Ali
	Gender M
	Country of Stay Pakistan
	Identity Number 35202-1234567-1
	Date of Birth 01.01.1995
	Date of Issue 01.01.2020
	Date of Expiry 01.01.2030
	Cardholder Signature
	NADRA
	"""
	back = """
	Present Address House 12 Lahore Punjab
	Permanent Address House 12 Lahore Punjab
	Card Serial No 123456789
	35202-1234567-1
	"""

	def test_reads_ocr_from_the_multipart_form(self):
		fake_frappe = SimpleNamespace(
			local=SimpleNamespace(
				request=SimpleNamespace(form={"cnic_front_ocr": self.front}),
				form_dict={},
			)
		)
		with patch("aqua_mart.api.seller.frappe", fake_frappe):
			self.assertEqual(_multipart_text({}, "cnic_front_ocr"), self.front)

	def test_accepts_matching_front_and_back(self):
		errors = _cnic_validation_errors(self.front, self.back, b"front", b"back")
		self.assertEqual(errors, {})

	def test_accepts_back_with_one_reverse_face_label(self):
		errors = _cnic_validation_errors(
			self.front,
			"Present Address House 12 Lahore",
			b"front",
			b"back",
		)
		self.assertEqual(errors, {})

	def test_rejects_front_in_back_slot(self):
		second_front_photo = self.front.replace("Muhammad Saad", "Muhammad Saad Khan")
		errors = _cnic_validation_errors(
			self.front,
			second_front_photo,
			b"front-one",
			b"front-two",
		)
		self.assertIn("front side", errors["cnic_back"].lower())

	def test_rejects_duplicate_image_bytes(self):
		errors = _cnic_validation_errors(self.front, self.back, b"same", b"same")
		self.assertIn("same cnic photo", errors["cnic_back"].lower())
