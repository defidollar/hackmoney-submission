const BPool = artifacts.require('BPool');
const BFactory = artifacts.require('BFactory');

const DefiDollarCore = artifacts.require("DefiDollarCore");
const DefiDollarToken = artifacts.require("DefiDollarToken");
const Reserve = artifacts.require("Reserve");
const MockIAToken = artifacts.require("MockIAToken");

const toWei = web3.utils.toWei;
const fromWei = web3.utils.fromWei;
const toBN =web3.utils.toBN;
const MAX = web3.utils.toTwosComplement(-1);

contract("DefiDollarCore", accounts => {
  const admin = accounts[0]
  const user1 = accounts[1]

  before(async function() {
    this.core = await DefiDollarCore.deployed()
    this.bFactory = await BFactory.deployed()
    this.defiDollarToken = await DefiDollarToken.deployed()
    this.numReserves = await this.core.numReserves()
    this.reserves = []
    for (let i = 0; i < this.numReserves; i++) {
      this.reserves.push(await Reserve.at(await this.core.reserves(i)))
    }
  })

  it('initialize core', async function() {
    const amount = toWei('100')
    const balances = []
    const denorm = []
    for (let i = 0; i < this.numReserves; i++) {
      await this.reserves[i].mint(admin, toWei('100000'))
      await this.reserves[i].approve(this.core.address, MAX)
      balances.push(amount)
      denorm.push(web3.utils.toWei('25')) // Required %age share / 2
    }
    await this.core.initialize(
      this.defiDollarToken.address,
      this.bFactory.address,
      balances,
      denorm
    )
  })

  it('core has bpool balance', async function() {
    this.bpool = await BPool.at(await this.core.bpool())
    assert.equal(await this.bpool.balanceOf(this.core.address), toWei('100'))
  })

  it('admin has dUSD balance', async function() {
    assert.equal(await this.defiDollarToken.balanceOf(admin), toWei('100'))
  })

  it('mintExactIn', async function() {
    const reserve = this.reserves[0]
    const tokenAmountIn = toWei('20')
    const initialBalance = await this.defiDollarToken.balanceOf(admin)
    const poolAmountOut = await this.core.mintExactIn.call(reserve.address, tokenAmountIn, 0, admin)
    await this.core.mintExactIn(reserve.address, tokenAmountIn, 0, admin)
    const finalBalance = await this.defiDollarToken.balanceOf(admin)
    assert.equal(finalBalance.toString(), initialBalance.add(poolAmountOut).toString())
    // console.log(fromWei(finalBalance))
  })

  it('mintExactOut', async function() {
    const reserve = this.reserves[1]
    const poolAmountOut = toBN(toWei('10')) // each poolToken is worth approx $2
    const initialBalance = await this.defiDollarToken.balanceOf(admin)
    const initialReserveBalance = await reserve.balanceOf(admin)
    // maxAmountIn is a little greater than what poolAmountOut pool tokens will be worth
    const maxAmountIn = toWei('25')
    const tokenAmountIn = await this.core.mintExactOut.call(reserve.address, poolAmountOut, maxAmountIn, admin)

    await this.core.mintExactOut(reserve.address, poolAmountOut, maxAmountIn, admin)
    const finalBalance = await this.defiDollarToken.balanceOf(admin)
    const finalReserveBalance = await reserve.balanceOf(admin)
    assert.equal(finalBalance.toString(), initialBalance.add(poolAmountOut).toString())
    assert.equal(finalReserveBalance.toString(), initialReserveBalance.sub(tokenAmountIn).toString())
    // console.log(fromWei(finalBalance))
  })

  it('redeemExact', async function() {
    const reserve = this.reserves[0]
    const poolAmountIn = toBN(toWei('5'))
    const initialBalance = await this.defiDollarToken.balanceOf(admin)
    const initialReserveBalance = await reserve.balanceOf(admin)
    const tokenAmountOut = await this.core.redeemExact.call(reserve.address, poolAmountIn, 0)

    await this.core.redeemExact(reserve.address, poolAmountIn, 0)
    const finalBalance = await this.defiDollarToken.balanceOf(admin)
    const finalReserveBalance = await reserve.balanceOf(admin)
    assert.equal(finalBalance.toString(), initialBalance.sub(poolAmountIn).toString())
    assert.equal(finalReserveBalance.toString(), initialReserveBalance.add(tokenAmountOut).toString())
  })

  it('redeemExactOut', async function() {
    const reserve = this.reserves[1]
    const tokenAmountOut = toBN(toWei('13'))
    const initialBalance = await this.defiDollarToken.balanceOf(admin)
    // console.log(fromWei(initialBalance))
    const initialReserveBalance = await reserve.balanceOf(admin)
    const poolAmountIn = await this.core.redeemExactOut.call(reserve.address, tokenAmountOut, MAX)

    await this.core.redeemExactOut(reserve.address, tokenAmountOut, MAX)
    const finalBalance = await this.defiDollarToken.balanceOf(admin)
    const finalReserveBalance = await reserve.balanceOf(admin)
    assert.equal(finalBalance.toString(), initialBalance.sub(poolAmountIn).toString())
    assert.equal(finalReserveBalance.toString(), initialReserveBalance.add(tokenAmountOut).toString())
    // console.log(fromWei(finalBalance))
  })

  it('swapExactAmountOut', async function() {
    this.aTokens = []
    const _aTokens = await this.bpool.getCurrentTokens()
    for (let i = 0; i < _aTokens.length; i++) {
      this.aTokens.push(await MockIAToken.at(_aTokens[i]))
      assert.equal(await this.core.reserveToAtoken(this.reserves[i].address), _aTokens[i])
    }
    const tokenIn = this.aTokens[0]
    const tokenOut = this.aTokens[1]
    const tokenAmountOut = toBN(toWei('3.6'))
    const maxAmountIn = toWei('20')
    await tokenIn.mint(user1, maxAmountIn, { from: admin })
    await tokenIn.approve(this.bpool.address, MAX, { from: user1 })
    const iUserBalanceTokenIn = await tokenIn.balanceOf(user1)
    const iPoolBalanceTokenIn = await tokenIn.balanceOf(this.bpool.address)
    const iUserBalanceTokenOut = await tokenOut.balanceOf(user1)
    const iPoolBalanceTokenOut = await tokenOut.balanceOf(this.bpool.address)
    const { tokenAmountIn, spotPriceAfter } = await this.bpool.swapExactAmountOut.call(
      tokenIn.address, maxAmountIn, tokenOut.address, tokenAmountOut, MAX, { from: user1 })
    await this.bpool.swapExactAmountOut(tokenIn.address, maxAmountIn, tokenOut.address, tokenAmountOut, MAX, { from: user1 })

    assert.equal((await tokenIn.balanceOf(user1)).toString(), iUserBalanceTokenIn.sub(tokenAmountIn).toString())
    assert.equal((await tokenOut.balanceOf(user1)).toString(), iUserBalanceTokenOut.add(tokenAmountOut).toString())
    assert.equal((await tokenIn.balanceOf(this.bpool.address)).toString(), iPoolBalanceTokenIn.add(tokenAmountIn).toString())
    assert.equal((await tokenOut.balanceOf(this.bpool.address)).toString(), iPoolBalanceTokenOut.sub(tokenAmountOut).toString())
  })

  it('swapExactAmountIn', async function() {
    const tokenIn = this.aTokens[0]
    const tokenOut = this.aTokens[1]
    const tokenAmountIn = toBN(toWei('10.987'))
    await tokenIn.mint(user1, tokenAmountIn, { from: admin })
    const iUserBalanceTokenIn = await tokenIn.balanceOf(user1)
    const iPoolBalanceTokenIn = await tokenIn.balanceOf(this.bpool.address)
    const iUserBalanceTokenOut = await tokenOut.balanceOf(user1)
    const iPoolBalanceTokenOut = await tokenOut.balanceOf(this.bpool.address)
    const { tokenAmountOut, spotPriceAfter } = await this.bpool.swapExactAmountIn.call(
      tokenIn.address, tokenAmountIn, tokenOut.address, 0, MAX, { from: user1 })
    await this.bpool.swapExactAmountIn(tokenIn.address, tokenAmountIn, tokenOut.address, 0, MAX, { from: user1 })

    assert.equal((await tokenIn.balanceOf(user1)).toString(), iUserBalanceTokenIn.sub(tokenAmountIn).toString())
    assert.equal((await tokenOut.balanceOf(user1)).toString(), iUserBalanceTokenOut.add(tokenAmountOut).toString())
    assert.equal((await tokenIn.balanceOf(this.bpool.address)).toString(), iPoolBalanceTokenIn.add(tokenAmountIn).toString())
    assert.equal((await tokenOut.balanceOf(this.bpool.address)).toString(), iPoolBalanceTokenOut.sub(tokenAmountOut).toString())
  })
})
