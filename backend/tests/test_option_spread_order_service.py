import unittest

from app.services.option_spread_order_service import (
    OptionLeg,
    SellPutSpread,
    calculate_sell_put_spread_preview,
    parse_occ_option_symbol,
    validate_sell_put_spread,
)


class OptionSpreadOrderServiceTests(unittest.TestCase):
    def test_parse_occ_option_symbol(self):
        parsed = parse_occ_option_symbol("QQQ260116P00480000")

        self.assertEqual(parsed["underlying"], "QQQ")
        self.assertEqual(parsed["expiry"], "20260116")
        self.assertEqual(parsed["put_call"], "P")
        self.assertEqual(parsed["strike"], 480.0)

    def test_validate_sell_put_spread_accepts_vertical_put_credit_spread(self):
        spread = SellPutSpread(
            underlying="QQQ",
            quantity=2,
            short_leg=OptionLeg(
                option_symbol="QQQ260116P00480000",
                action="SELL",
                put_call="P",
                expiry="20260116",
                strike=480.0,
            ),
            long_leg=OptionLeg(
                option_symbol="QQQ260116P00470000",
                action="BUY",
                put_call="P",
                expiry="20260116",
                strike=470.0,
            ),
            net_credit=1.25,
            profit_exit_percent=30.0,
        )

        validated = validate_sell_put_spread(spread)

        self.assertEqual(validated.short_leg.action, "SELL")
        self.assertEqual(validated.long_leg.action, "BUY")
        self.assertEqual(validated.short_leg.strike, 480.0)
        self.assertEqual(validated.long_leg.strike, 470.0)

    def test_validate_rejects_long_strike_above_short_strike(self):
        spread = SellPutSpread(
            underlying="QQQ",
            quantity=1,
            short_leg=OptionLeg(
                option_symbol="QQQ260116P00480000",
                action="SELL",
                put_call="P",
                expiry="20260116",
                strike=480.0,
            ),
            long_leg=OptionLeg(
                option_symbol="QQQ260116P00490000",
                action="BUY",
                put_call="P",
                expiry="20260116",
                strike=490.0,
            ),
            net_credit=1.25,
            profit_exit_percent=30.0,
        )

        with self.assertRaises(ValueError) as ctx:
            validate_sell_put_spread(spread)

        self.assertIn("Short put strike must be greater than long put strike", str(ctx.exception))

    def test_preview_math_for_credit_spread(self):
        spread = SellPutSpread(
            underlying="QQQ",
            quantity=2,
            short_leg=OptionLeg(
                option_symbol="QQQ260116P00480000",
                action="SELL",
                put_call="P",
                expiry="20260116",
                strike=480.0,
            ),
            long_leg=OptionLeg(
                option_symbol="QQQ260116P00470000",
                action="BUY",
                put_call="P",
                expiry="20260116",
                strike=470.0,
            ),
            net_credit=1.25,
            profit_exit_percent=30.0,
        )

        preview = calculate_sell_put_spread_preview(spread)

        self.assertEqual(preview["width"], 10.0)
        self.assertEqual(preview["max_profit"], 250.0)
        self.assertEqual(preview["max_loss"], 1750.0)
        self.assertEqual(preview["breakeven"], 478.75)
        self.assertEqual(preview["profit_exit_debit"], 0.875)


if __name__ == "__main__":
    unittest.main()
