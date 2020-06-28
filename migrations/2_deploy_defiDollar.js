const assert = require('assert')
const fs = require('fs')

const MockLendingPool = artifacts.require("MockLendingPool");
const aToken = artifacts.require("MockIAToken");

const TMath = artifacts.require('TMath');
// const BFactory = artifacts.require('BFactory');
const BPool = artifacts.require('ModifiedBPool');

const Core = artifacts.require("Core");
const AavePlugin = artifacts.require("AavePlugin");
const UniswapPlugin = artifacts.require("UniswapPlugin");
const MockUniswap = artifacts.require("MockUniswap");
const Reserve = artifacts.require("Reserve");
const Oracle = artifacts.require("Oracle");
const Aggregator = artifacts.require("MockAggregator");
const Pool = artifacts.require('LBP');

const NUM_RESERVES = parseInt(process.env.NUM_RESERVES) || 2;
const toBN = web3.utils.toBN

module.exports = async function (deployer, network, accounts) {
  console.log('running migrations...')
  const admin = accounts[0]
  const contracts = { tokens: {}, aave: {}, defidollar: {} }

  const initialAmount = web3.utils.toWei('100')
  const tokenTicker = ['DAI', 'TUSD', 'MKR']

  // Deploy erc20 reserves
  const reserves = []
  for (let i = 0; i < NUM_RESERVES; i++) {
    reserves.push(await Reserve.new())
    contracts.tokens[tokenTicker[i]] = reserves[i].address
    // contracts.tokens[`TOK${i}`] = reserves[i].address
    await reserves[i].mint(admin, initialAmount)
  }
  const mkr = await Reserve.new()
  contracts.tokens[tokenTicker[2]] = mkr.address
  await mkr.mint(admin, initialAmount)

  // Deploy ATokens and oracle price aggregators
  const aTokens = []
  const aggregators = []
  const lendingPool = await deployer.deploy(MockLendingPool, reserves.map(r => r.address))
  const ethPrice = toBN(200)
  for (let i = 0; i < NUM_RESERVES; i++) {
    aTokens.push(await aToken.at(await lendingPool.rToA(reserves[i].address)))
    contracts.aave[`a${tokenTicker[i]}`] = aTokens[i].address
    aggregators.push(await Aggregator.new())
    // set price = $1 but relative to eth
    await aggregators[i].setLatestAnswer(toBN(web3.utils.toWei('1')).div(ethPrice))
  }
  // console.log({aTokens: aTokens.map(a => a.address)})

  // Deploy actual oracle
  const ethUsdAgg = await Aggregator.new()
  // The latestAnswer value for all USD reference data contracts is multiplied by 100000000 before being written on-chain and
  await ethUsdAgg.setLatestAnswer(ethPrice.mul(toBN('100000000')))
  await deployer.deploy(Oracle, aggregators.map(a => a.address), ethUsdAgg.address)
  const oracle = await Oracle.deployed()

  // Deploy Balancer things
  await deployer.deploy(TMath);
  // await deployer.deploy(BFactory);
  await deployer.deploy(BPool);
  const bPool = await BPool.deployed()
  contracts.defidollar.bpool = bPool.address

  // Balancer Pool

  const amount = web3.utils.toWei(process.env.INITIAL_AMOUNT || '50') // of each
  const weight = web3.utils.toWei('10') // giving equal weight to each coin
  const swapFee = web3.utils.toBN('10').pow(web3.utils.toBN('12')) // min_fee
  await deployer.deploy(
    Pool,
    BPool.address, // passing bpool address instead
    aTokens.map(a => a.address), // tokens
    (new Array(NUM_RESERVES)).fill(amount), // startBalances
    (new Array(NUM_RESERVES)).fill(weight), // startWeights
    (new Array(NUM_RESERVES)).fill(weight), // endWeights
    swapFee
  );
  const pool = await Pool.deployed()
  bPool.setController(pool.address)
  contracts.defidollar.pool = pool.address

  for (let i = 0; i < NUM_RESERVES; i++) {
    // get atokens in exchange of reserve tokens
    await reserves[i].approve(lendingPool.address, web3.utils.toWei('70'))
    await lendingPool.deposit(reserves[i].address, web3.utils.toWei('70'), 0)
    // aTokens[i].mint(admin, web3.utils.toWei('1000000000'))
    await aTokens[i].approve(pool.address, amount)
  }
  const initialSupply = web3.utils.toBN(amount).mul(web3.utils.toBN(NUM_RESERVES)) // assuming each coin is $1
  await pool.createPool(initialSupply)
  assert.equal((await pool.balanceOf(admin)).toString(), initialSupply.toString())

  // Deploy Core
  await deployer.deploy(
    Core,
    reserves.map(r => r.address),
    aTokens.map(r => r.address),
    pool.address,
    oracle.address
  );
  const core = await Core.deployed()
  await pool.setController(core.address)
  contracts.defidollar.core = core.address

  // Deploy Aave
  await deployer.deploy(
    AavePlugin,
    reserves.map(r => r.address),
    aTokens.map(r => r.address),
    lendingPool.address,
    lendingPool.address, // _aaveLendingPoolCore but it is irrelevant here
    core.address,
    pool.address
  )
  contracts.defidollar.aave = AavePlugin.address

  // Deploy Uniswap
  await deployer.deploy(MockUniswap)
  await deployer.deploy(
    UniswapPlugin,
    MockUniswap.address,
    AavePlugin.address,
    pool.address
  )
  contracts.uniswap = { router: MockUniswap.address }
  contracts.defidollar.uniswapPlugin = UniswapPlugin.address
  fs.writeFileSync('./addresses.json', JSON.stringify({ contracts }, null, 2))
};
