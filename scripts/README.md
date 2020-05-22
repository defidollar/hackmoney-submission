```
INITIAL_AMOUNT=500000 truffle migrate --reset && truffle exec scripts/simulate.js
```
```
{ deviations:
   { dusd: 0.15343069657807362,
     'usd-coin': 0.20624925883791878,
     tether: 0.214674516952999 },
  profit: 355.64762907111043 }

{ deviations:
   { dusd: 0.2550739324790262,
     'usd-coin': 0.20624925883791878,
     'true-usd': 0.33654444004026673 },
  profit: 1259.6890281457277 }

{ deviations:
   { dusd: 0.6978653457506134,
     dai: 1.3879218964838727,
     'usd-coin': 0.20624925883791878 },
  profit: 1098.8219693643719 }
```

```
INITIAL_AMOUNT=50000 truffle migrate --reset && truffle exec scripts/simulate.js
```
```
{ deviations:
   { dusd: 0, dai: 1.3879218964838727, nusd: 2.962608757300444 },
  profit: 2033.237658171714,
  mp1: 51539.28556499885,
  mp2: 59770.47750485338 }
```

Newest
```
{ deviations:
   { dusd: 1.660823984670144,
     dai: 1.3879218964838727,
     nusd: 2.962608757300444 },
  profit: 205.4201867998646,
  maxPoolSize1: 5343.737016229948,
  maxPoolSize2: 5833.432132827918 }
```

```
{ deviations:
   { dusd: 1.1771590903883487,
     dai: 1.3879218964838727,
     nusd: 2.962608757300444 },
  profit: 204.50580773226955,
  maxPoolSize1: 5267.671333228876,
  maxPoolSize2: 5832.937804168374 }
```
