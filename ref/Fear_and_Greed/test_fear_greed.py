import unittest

import pandas as pd

from model_fear_greed_spx import classify_score, remove_placeholder_history


class FearGreedTests(unittest.TestCase):
    def test_classify_score(self):
        self.assertEqual(classify_score(10), "extreme fear")
        self.assertEqual(classify_score(34), "fear")
        self.assertEqual(classify_score(50), "neutral")
        self.assertEqual(classify_score(65), "greed")
        self.assertEqual(classify_score(90), "extreme greed")

    def test_placeholder_history_is_removed(self):
        frame = pd.DataFrame(
            {
                "Date": pd.date_range("2020-01-01", periods=15),
                "Fear_Greed_Score": [50.0] * 10 + [40, 41, 42, 43, 44],
                "SPX_Close": range(15),
            }
        )
        cleaned = remove_placeholder_history(frame)
        self.assertEqual(len(cleaned), 5)
        self.assertEqual(cleaned.iloc[0]["Fear_Greed_Score"], 40)


if __name__ == "__main__":
    unittest.main()
