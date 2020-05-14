# DefiDollar

```
npm run compile
npm run migrate
npm test
INITIAL_AMOUNT=50000 truffle migrate --reset && truffle exec scripts/simulate.js
```

### Deploy to Kovan
```
export API_KEY, MNEMONIC
npm run truffle exec scripts/deploy.js -- --network kovan
```
