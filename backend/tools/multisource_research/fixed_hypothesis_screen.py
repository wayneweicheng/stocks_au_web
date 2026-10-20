"""Pre-registered fixed-threshold technical/option screens on corrected August labels.

This is a discovery screen, not a portfolio simulator. It does not optimize
thresholds or use September/October outcomes. All tests and split boundaries
are fixed in source before execution; results include purged chronological
train/validation/final windows and matched-coverage unconditional comparators.
"""
from __future__ import annotations
import json
import inspect
from pathlib import Path
import numpy as np
import pandas as pd

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'data/strategy_runtime/20261018-b-research'
LABELS=BASE/'research_corrected/eligible-outcomes.csv'
TECH=BASE/'technical_features/causal-technical-features.csv'
OPTIONS=BASE/'option_features/option-daily-features.csv'
# Preserve the first run: its combined-family availability check was defective.
OUT=BASE/'fixed_hypothesis_screen_v2'
CUTOFF=pd.Timestamp('2026-08-31')
COST_BPS=(0,10,25,50)

# Each fixed directional condition is an independent registered trial. No
# thresholds are selected from the final segment. Technical and option-only
# families are screened without requiring a previous GEX trigger.
SCREEN_DEFS={
 'TECH_RSI_OVERSOLD_LONG':('TECHNICAL','RSI14',lambda d:d.RSI14<=30,'LONG'),
 'TECH_RSI_OVERBOUGHT_SHORT':('TECHNICAL','RSI14',lambda d:d.RSI14>=70,'SHORT'),
 'TECH_RSI_MIDLINE_UP_LONG':('TECHNICAL','RSI14',lambda d:(d.RSI14>=50)&(d.RSI14.groupby(d.ticker).shift(1)<50),'LONG'),
 'TECH_RSI_MIDLINE_DOWN_SHORT':('TECHNICAL','RSI14',lambda d:(d.RSI14<=50)&(d.RSI14.groupby(d.ticker).shift(1)>50),'SHORT'),
 'TECH_SMA50_TREND_LONG':('TECHNICAL','PriceDistSMA50Pct',lambda d:(d.PriceDistSMA50Pct>0)&(d.SMA50Slope5Pct>0),'LONG'),
 'TECH_SMA50_TREND_SHORT':('TECHNICAL','PriceDistSMA50Pct',lambda d:(d.PriceDistSMA50Pct<0)&(d.SMA50Slope5Pct<0),'SHORT'),
 'TECH_SMA50_STRETCH_LONG':('TECHNICAL','PriceDistSMA50Pct',lambda d:d.PriceDistSMA50Pct<=-2,'LONG'),
 'TECH_SMA50_STRETCH_SHORT':('TECHNICAL','PriceDistSMA50Pct',lambda d:d.PriceDistSMA50Pct>=2,'SHORT'),
 'TECH_BB_LOWER_REVERSION_LONG':('TECHNICAL','BB20PercentB',lambda d:d.BB20PercentB<=.10,'LONG'),
 'TECH_BB_UPPER_REVERSION_SHORT':('TECHNICAL','BB20PercentB',lambda d:d.BB20PercentB>=.90,'SHORT'),
 'TECH_BB_LOWER_BREAKDOWN_SHORT':('TECHNICAL','BB20PercentB',lambda d:d.BB20PercentB<0,'SHORT'),
 'TECH_BB_UPPER_BREAKOUT_LONG':('TECHNICAL','BB20PercentB',lambda d:d.BB20PercentB>1,'LONG'),
 'TECH_BB_SQUEEZE_TREND_LONG':('TECHNICAL','BB20BandwidthRank60',lambda d:(d.BB20BandwidthRank60<=.20)&(d.CloseAboveSMA50==1),'LONG'),
 'TECH_BB_SQUEEZE_TREND_SHORT':('TECHNICAL','BB20BandwidthRank60',lambda d:(d.BB20BandwidthRank60<=.20)&(d.CloseAboveSMA50==0),'SHORT'),
 'TECH_MACD_POSITIVE_LONG':('TECHNICAL','MACDHistogram',lambda d:(d.MACDHistogram>0)&(d.MACDHistogramChange3>0),'LONG'),
 'TECH_MACD_NEGATIVE_SHORT':('TECHNICAL','MACDHistogram',lambda d:(d.MACDHistogram<0)&(d.MACDHistogramChange3<0),'SHORT'),
 'TECH_SUPPORT_NEAR_LONG':('TECHNICAL','DistPriorLow20ATR',lambda d:(d.DistPriorLow20ATR>=0)&(d.DistPriorLow20ATR<=.5),'LONG'),
 'TECH_RESISTANCE_NEAR_SHORT':('TECHNICAL','DistPriorHigh20ATR',lambda d:(d.DistPriorHigh20ATR>=0)&(d.DistPriorHigh20ATR<=.5),'SHORT'),
 'TECH_PRIOR_DAY_PIVOT_ABOVE_LONG':('TECHNICAL','DistPriorDayPivotATR',lambda d:d.DistPriorDayPivotATR>0,'LONG'),
 'TECH_PRIOR_DAY_PIVOT_BELOW_SHORT':('TECHNICAL','DistPriorDayPivotATR',lambda d:d.DistPriorDayPivotATR<0,'SHORT'),
 'TECH_PRIOR_WEEK_PIVOT_ABOVE_LONG':('TECHNICAL','DistPriorWeekPivotATR',lambda d:d.DistPriorWeekPivotATR>0,'LONG'),
 'TECH_PRIOR_WEEK_PIVOT_BELOW_SHORT':('TECHNICAL','DistPriorWeekPivotATR',lambda d:d.DistPriorWeekPivotATR<0,'SHORT'),
 'TECH_PRIOR_MONTH_PIVOT_ABOVE_LONG':('TECHNICAL','DistPriorMonthPivotATR',lambda d:d.DistPriorMonthPivotATR>0,'LONG'),
 'TECH_PRIOR_MONTH_PIVOT_BELOW_SHORT':('TECHNICAL','DistPriorMonthPivotATR',lambda d:d.DistPriorMonthPivotATR<0,'SHORT'),
 'TECH_CONFIRMED_BULLISH_DIVERGENCE_LONG':('TECHNICAL','PriceRSISlopeDivergence',lambda d:(d.CloseSlope20PctPerDay<0)&(d.RSISlope20PerDay>0),'LONG'),
 'TECH_CONFIRMED_BEARISH_DIVERGENCE_SHORT':('TECHNICAL','PriceRSISlopeDivergence',lambda d:(d.CloseSlope20PctPerDay>0)&(d.RSISlope20PerDay<0),'SHORT'),
 'TECH_HIGH_RELATIVE_VOLUME_BREAKOUT_LONG':('TECHNICAL','RelativeVolume20',lambda d:(d.RelativeVolume20>=1.5)&(d.BreakPriorHigh20==1),'LONG'),
 'TECH_HIGH_RELATIVE_VOLUME_BREAKDOWN_SHORT':('TECHNICAL','RelativeVolume20',lambda d:(d.RelativeVolume20>=1.5)&(d.BreakPriorLow20==1),'SHORT'),
 'TECH_CONFIRMED_PIVOT_HIGH_NEAR_SHORT':('TECHNICAL','LastPivotHighDistanceATR',lambda d:(d.LastPivotHighDistanceATR>=0)&(d.LastPivotHighDistanceATR<=.5),'SHORT'),
 'TECH_CONFIRMED_PIVOT_LOW_NEAR_LONG':('TECHNICAL','LastPivotLowDistanceATR',lambda d:(d.LastPivotLowDistanceATR>=0)&(d.LastPivotLowDistanceATR<=.5),'LONG'),
 'OPTION_VOLUME_HIGH_LONG':('OPTION','TotalVolumePrior60Rank',lambda d:d.TotalVolumePrior60Rank>=.80,'LONG'),
 'OPTION_VOLUME_HIGH_SHORT':('OPTION','TotalVolumePrior60Rank',lambda d:d.TotalVolumePrior60Rank>=.80,'SHORT'),
 'OPTION_OI_HIGH_LONG':('OPTION','TotalOpenInterestPrior60Rank',lambda d:d.TotalOpenInterestPrior60Rank>=.80,'LONG'),
 'OPTION_OI_HIGH_SHORT':('OPTION','TotalOpenInterestPrior60Rank',lambda d:d.TotalOpenInterestPrior60Rank>=.80,'SHORT'),
 'OPTION_VOLUME_OI_HIGH_LONG':('OPTION','VolumeOIRatioPrior60Rank',lambda d:d.VolumeOIRatioPrior60Rank>=.80,'LONG'),
 'OPTION_VOLUME_OI_HIGH_SHORT':('OPTION','VolumeOIRatioPrior60Rank',lambda d:d.VolumeOIRatioPrior60Rank>=.80,'SHORT'),
 'OPTION_PUT_CALL_VOLUME_HIGH_LONG':('OPTION','PutCallVolumeRatioPrior60Rank',lambda d:d.PutCallVolumeRatioPrior60Rank>=.80,'LONG'),
 'OPTION_PUT_CALL_VOLUME_HIGH_SHORT':('OPTION','PutCallVolumeRatioPrior60Rank',lambda d:d.PutCallVolumeRatioPrior60Rank>=.80,'SHORT'),
 'OPTION_IV_HIGH_LONG':('OPTION','IVVolumeWeightedPrior60Rank',lambda d:d.IVVolumeWeightedPrior60Rank>=.80,'LONG'),
 'OPTION_IV_HIGH_SHORT':('OPTION','IVVolumeWeightedPrior60Rank',lambda d:d.IVVolumeWeightedPrior60Rank>=.80,'SHORT'),
 'OPTION_IV_LOW_LONG':('OPTION','IVVolumeWeightedPrior60Rank',lambda d:d.IVVolumeWeightedPrior60Rank<=.20,'LONG'),
 'OPTION_IV_LOW_SHORT':('OPTION','IVVolumeWeightedPrior60Rank',lambda d:d.IVVolumeWeightedPrior60Rank<=.20,'SHORT'),
 'OPTION_NEAR_EXPIRY_VOLUME_LONG':('OPTION','Near45VolumeSharePrior60Rank',lambda d:d.Near45VolumeSharePrior60Rank>=.80,'LONG'),
 'OPTION_NEAR_EXPIRY_VOLUME_SHORT':('OPTION','Near45VolumeSharePrior60Rank',lambda d:d.Near45VolumeSharePrior60Rank>=.80,'SHORT'),
 'OPTION_SPREAD_WIDE_LONG':('OPTION','ValidSpreadVolumeWeightedPrior60Rank',lambda d:d.ValidSpreadVolumeWeightedPrior60Rank>=.80,'LONG'),
 'OPTION_SPREAD_WIDE_SHORT':('OPTION','ValidSpreadVolumeWeightedPrior60Rank',lambda d:d.ValidSpreadVolumeWeightedPrior60Rank>=.80,'SHORT'),
 'OPTION_GAMMA_ACTIVITY_LONG':('OPTION','AbsGammaVolumeWeightedPrior60Rank',lambda d:d.AbsGammaVolumeWeightedPrior60Rank>=.80,'LONG'),
 'OPTION_GAMMA_ACTIVITY_SHORT':('OPTION','AbsGammaVolumeWeightedPrior60Rank',lambda d:d.AbsGammaVolumeWeightedPrior60Rank>=.80,'SHORT'),
 'OPTION_VEGA_ACTIVITY_LONG':('OPTION','AbsVegaVolumeWeightedPrior60Rank',lambda d:d.AbsVegaVolumeWeightedPrior60Rank>=.80,'LONG'),
 'OPTION_VEGA_ACTIVITY_SHORT':('OPTION','AbsVegaVolumeWeightedPrior60Rank',lambda d:d.AbsVegaVolumeWeightedPrior60Rank>=.80,'SHORT'),
 'COMBO_BB_LOWER_GEX_LOW_LONG':('COMBINED',('BB20PercentB','GEX_ZScore'),lambda d:(d.BB20PercentB<=.10)&(d.GEX_ZScore<=-1.0),'LONG'),
 'COMBO_BB_LOWER_GEX_HIGH_LONG':('COMBINED',('BB20PercentB','GEX_ZScore'),lambda d:(d.BB20PercentB<=.10)&(d.GEX_ZScore>=1.0),'LONG'),
 'COMBO_BB_LOWER_IV_HIGH_LONG':('COMBINED',('BB20PercentB','IVVolumeWeightedPrior60Rank'),lambda d:(d.BB20PercentB<=.10)&(d.IVVolumeWeightedPrior60Rank>=.80),'LONG'),
 'COMBO_BB_LOWER_IV_LOW_LONG':('COMBINED',('BB20PercentB','IVVolumeWeightedPrior60Rank'),lambda d:(d.BB20PercentB<=.10)&(d.IVVolumeWeightedPrior60Rank<=.20),'LONG'),
 'COMBO_RSI_OVERSOLD_GEX_LOW_LONG':('COMBINED',('RSI14','GEX_ZScore'),lambda d:(d.RSI14<=30)&(d.GEX_ZScore<=-1.0),'LONG'),
 'COMBO_SUPPORT_OI_HIGH_LONG':('COMBINED',('DistPriorLow20ATR','TotalOpenInterestPrior60Rank'),lambda d:(d.DistPriorLow20ATR>=0)&(d.DistPriorLow20ATR<=.5)&(d.TotalOpenInterestPrior60Rank>=.80),'LONG'),
 'COMBO_RESISTANCE_IV_HIGH_SHORT':('COMBINED',('DistPriorHigh20ATR','IVVolumeWeightedPrior60Rank'),lambda d:(d.DistPriorHigh20ATR>=0)&(d.DistPriorHigh20ATR<=.5)&(d.IVVolumeWeightedPrior60Rank>=.80),'SHORT'),
 'COMBO_MACD_VOLUME_HIGH_LONG':('COMBINED',('MACDHistogram','TotalVolumePrior60Rank'),lambda d:(d.MACDHistogram>0)&(d.TotalVolumePrior60Rank>=.80),'LONG'),
 'MARKET_VIX_LOW_LONG':('MARKET','VIX',lambda d:d.VIX<=20,'LONG'),
 'MARKET_VIX_HIGH_SHORT':('MARKET','VIX',lambda d:d.VIX>20,'SHORT'),
 'MARKET_QQQ_UP_LONG':('MARKET','QQQ_TodayChange',lambda d:d.QQQ_TodayChange>0,'LONG'),
 'MARKET_QQQ_DOWN_SHORT':('MARKET','QQQ_TodayChange',lambda d:d.QQQ_TodayChange<0,'SHORT'),
}



def feature_eligible_mask(panel: pd.DataFrame, features: str | tuple[str, ...]) -> pd.Series:
 """Each input to a conjunction must be available; missing columns fail closed."""
 required = (features,) if isinstance(features,str) else features
 eligible = pd.Series(True,index=panel.index)
 for name in required:
  if name not in panel:
   return pd.Series(False,index=panel.index)
  eligible &= panel[name].notna()
 return eligible


def metrics(values,cost_pct=0.0):
 x=pd.to_numeric(values,errors='coerce').dropna()-cost_pct
 if not len(x):return {'n':0,'wr_pct':None,'mean_net_pct':None,'pf_net':None}
 wins=x[x>0];losses=x[x<=0];gross_loss=abs(float(losses.sum()))
 return {'n':len(x),'wr_pct':float((x>0).mean()*100),'mean_net_pct':float(x.mean()),'pf_net':float(wins.sum()/gross_loss) if gross_loss else None}


def main():
 OUT.mkdir(parents=True,exist_ok=True)
 labels=pd.read_csv(LABELS);labels['market_date']=pd.to_datetime(labels.market_date)
 tech=pd.read_csv(TECH);tech['ObservationDate']=pd.to_datetime(tech.ObservationDate);tech=tech.rename(columns={'ASXCode':'ticker','ObservationDate':'market_date'})
 option=pd.read_csv(OPTIONS);option['ObservationDate']=pd.to_datetime(option.ObservationDate);option=option.rename(columns={'ASXCode':'ticker','ObservationDate':'market_date'})
 panel=labels.merge(tech,on=['ticker','market_date'],how='left',validate='one_to_one',suffixes=('','_tech')).merge(option,on=['ticker','market_date'],how='left',validate='one_to_one',suffixes=('','_option'))
 panel=panel.sort_values(['ticker','market_date']).reset_index(drop=True)
 dates=sorted(panel.market_date.dropna().unique());n=len(dates);i1=int(n*.60);i2=int(n*.80);d1=dates[i1];d2=dates[i2]
 panel['split']=np.select([panel.market_date<pd.Timestamp(d1),panel.market_date<pd.Timestamp(d2)],['TRAIN','VALIDATION'],'FINAL_RESEARCH_TAIL')
 split_manifest={'date_count':n,'train_raw_end_exclusive':str(pd.Timestamp(d1).date()),'validation_start':str(pd.Timestamp(d1).date()),'final_start':str(pd.Timestamp(d2).date()),'final_end_inclusive':str(pd.Timestamp(dates[-1]).date()),'purge_policy':'For each D1/D3/D5, retain a row in a split only if its scheduled exit date is strictly before the next split start; final rows require resolved labels. This purges label overlap across split boundaries.','thresholds_fixed_in_source':True,'thresholds_selected_from_final':False}
 (OUT/'split-manifest.json').write_text(json.dumps(split_manifest,indent=2)+'\n',encoding='utf-8')
 registry=[{'experiment_id':name,'family':v[0],'features':list(v[1]) if isinstance(v[1],tuple) else [v[1]],'condition_source':inspect.getsource(v[2]).strip(),'direction':v[3],'horizons':['D1','D3','D5'],'costs_bps':list(COST_BPS),'status':'PRE_REGISTERED_FIXED_SCREEN','selection_rule':'No threshold selected; final tail is report-only.'} for name,v in SCREEN_DEFS.items()]
 pd.DataFrame(registry).to_json(OUT/'hypotheses.jsonl',orient='records',lines=True)
 rows=[]
 for experiment,(family,feature,mask_func,direction) in SCREEN_DEFS.items():
  try: masks=mask_func(panel).fillna(False)
  except Exception as e:
   rows.append({'experiment_id':experiment,'family':family,'feature':feature,'direction':direction,'status':'FEATURE_ERROR','error':repr(e)});continue
  for horizon in ('D1','D3','D5'):
   ret_col=f'ret_{horizon}';exit_col=f'exit_{horizon}';data=panel[pd.to_numeric(panel[ret_col],errors='coerce').notna()].copy();data['_return']=pd.to_numeric(data[ret_col],errors='coerce')*(1 if direction=='LONG' else -1);data['_exit']=pd.to_datetime(data[exit_col],errors='coerce');valid_feature=feature_eligible_mask(panel,feature);signal=masks.reindex(data.index,fill_value=False)
   split_dates={'TRAIN':pd.Timestamp(d1),'VALIDATION':pd.Timestamp(d2),'FINAL_RESEARCH_TAIL':pd.Timestamp(CUTOFF)+pd.Timedelta(days=1)}
   for split, next_boundary in split_dates.items():
    sub=data[data.split==split].copy()
    # Purge labels extending across the next split boundary.
    if split!='FINAL_RESEARCH_TAIL':sub=sub[sub._exit<next_boundary]
    else:sub=sub[sub._exit<=CUTOFF]
    matched=valid_feature.reindex(sub.index,fill_value=False)
    triggered=signal.reindex(sub.index,fill_value=False)&matched
    for cost in COST_BPS:
     cost_pct=cost/100.0
     result={'experiment_id':experiment,'family':family,'feature':'+'.join(feature) if isinstance(feature,tuple) else feature,'direction':direction,'horizon':horizon,'split':split,'cost_bps_round_trip':cost,'screen_frequency_pct':float(triggered.mean()*100) if len(sub) else None,'available_n':int(matched.sum()),**{f'signal_{k}':v for k,v in metrics(sub.loc[triggered,'_return'],cost_pct).items()},**{f'matched_baseline_{k}':v for k,v in metrics(sub.loc[matched,'_return'],cost_pct).items()}}
     rows.append(result)
 results=pd.DataFrame(rows);results.to_csv(OUT/'fixed-screen-results.csv',index=False)
 print(json.dumps({'registered_tests':len(SCREEN_DEFS),'result_rows':len(results),'split':split_manifest,'input_symbols':int(panel.ticker.nunique()),'input_rows':len(panel)},indent=2,default=str))

if __name__=='__main__':main()
