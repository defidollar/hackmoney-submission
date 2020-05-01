const DefiDollarCore = artifacts.require("DefiDollarCore");
const DefiDollarToken = artifacts.require("DefiDollarToken");
const LendingPool = artifacts.require("MockLendingPool");
const aToken = artifacts.require("MockIAToken");
const BFactory = artifacts.require('BFactory');
const BPool = artifacts.require('BPool');
const Reserve = artifacts.require("Reserve");

const NUM_RESERVES = 2;

module.exports = async function (deployer, network, accounts) {
  const reserves = []
  const aTokens = []
  for (let i = 0; i < NUM_RESERVES; i++) {
    reserves.push(await Reserve.new())
  }
  const lendingPool = await LendingPool.new(reserves.map(r => r.address))
  for (let i = 0; i < NUM_RESERVES; i++) {
    aTokens.push(await aToken.at(await lendingPool.rToA(reserves[i].address)))
  }

  await deployer.deploy(DefiDollarCore,
    reserves.map(r => r.address),
    aTokens.map(r => r.address),
    lendingPool.address,
    lendingPool.address // core, doesn't matter for mocks
  );
  const core = await DefiDollarCore.deployed()
  await deployer.deploy(DefiDollarToken, core.address)
  const defiDollarToken = await DefiDollarToken.deployed()

  // initialize core
  const admin = accounts[0]
  for (let i = 0; i < this.numReserves; i++) {
    reserves.push(await Reserve.at(await this.core.reserves(i)))
  }
  // const amount = web3.utils.toWei('500000') // of each
  const amount = web3.utils.toWei('50') // of each
  const balances = []
  const denorm = []
  for (let i = 0; i < NUM_RESERVES; i++) {
    await reserves[i].mint(admin, amount)
    await reserves[i].approve(core.address, amount)
    balances.push(amount)
    denorm.push(web3.utils.toWei('25')) // Required %age share / 2
  }
  const bFactory = await BFactory.deployed()
  await core.initialize(
    defiDollarToken.address,
    bFactory.address,
    balances,
    denorm
  )

  // const aTokens = []
  // const bpool = await BPool.at(await core.bpool())
  // for (let i = 0; i < NUM_RESERVES; i++) {
  //   aTokens.push(await MockIAToken.at(this.reserves[i].address))
  // }
  // console.log(
  //   await aTokens[0].balanceOf(bpool.address),
  //   await aTokens[1].balanceOf(bpool.address)
  // )
};
