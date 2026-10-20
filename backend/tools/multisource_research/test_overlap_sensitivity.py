import sys
from pathlib import Path
import pandas as pd
sys.path.insert(0,str(Path(__file__).resolve().parent))
from overlap_sensitivity import select_tranches


def test_d5_close_position_blocks_same_ticker_d5_morning_entry():
    d=pd.DataFrame({'ticker':['A.US']*3,'market_date':pd.to_datetime(['2026-08-03','2026-08-04','2026-08-11']),
        'entry_date':pd.to_datetime(['2026-08-04','2026-08-05','2026-08-12']),
        'exit_D5':pd.to_datetime(['2026-08-10','2026-08-11','2026-08-18']),'ret_D5':[3,4,5]})
    selected,peak=select_tranches(d,1)
    assert selected.ret_D5.tolist()==[3,5]
    assert peak==1


def test_global_cap_deterministic_ticker_order():
    d=pd.DataFrame({'ticker':['B.US','A.US'],'market_date':pd.to_datetime(['2026-08-03']*2),
        'entry_date':pd.to_datetime(['2026-08-04']*2),'exit_D5':pd.to_datetime(['2026-08-10']*2),'ret_D5':[1,2]})
    selected,_=select_tranches(d,1,1)
    assert selected.ticker.tolist()==['A.US']
