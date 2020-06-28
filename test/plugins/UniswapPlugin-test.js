const utils = require('../../utils/utils')

const Reserve = artifacts.require("Reserve");

const toWei = web3.utils.toWei;
const fromWei = web3.utils.fromWei;
const toBN =web3.utils.toBN;
const MAX = web3.utils.toTwosComplement(-1);

contract.skip("UniswapPlugin", accounts => {
  const admin = accounts[0]
  let _artifacts

  before(async function() {
    _artifacts = await utils.getArtifacts(artifacts, { uniswap: true })
  })


  it('mintExactIn', async function() {
    const reserve = _artifacts.reserves[0]
    const initialBalance = await _artifacts.pool.balanceOf(admin)

    const tokenAmountIn = toWei('20')
    await reserve.mint(admin, tokenAmountIn)
    await reserve.approve(_artifacts.uniswap.address, tokenAmountIn)

    const poolAmountOut = await _artifacts.uniswap.mintExactIn.call(reserve.address, tokenAmountIn, 0, reserve.address)
    await _artifacts.uniswap.mintExactIn(reserve.address, tokenAmountIn, 0, reserve.address)

    const finalBalance = await _artifacts.pool.balanceOf(admin)
    assert.equal(finalBalance.toString(), initialBalance.add(poolAmountOut).toString())
    console.log({initialBalance: fromWei(initialBalance), finalBalance: fromWei(finalBalance)})
  })

  it('mintExactIn (tokenIn != reserveToken)', async function() {
    const tokenIn = await Reserve.new()
    const tokenAmountIn = toWei('20')
    await tokenIn.mint(admin, tokenAmountIn)
    await tokenIn.approve(_artifacts.uniswap.address, tokenAmountIn)

    const reserve = _artifacts.reserves[0]
    const initialBalance = await _artifacts.pool.balanceOf(admin)

    const poolAmountOut = await _artifacts.uniswap.mintExactIn.call(tokenIn.address, tokenAmountIn, 0, reserve.address)
    await _artifacts.uniswap.mintExactIn(tokenIn.address, tokenAmountIn, 0, reserve.address)

    const finalBalance = await _artifacts.pool.balanceOf(admin)
    assert.equal(finalBalance.toString(), initialBalance.add(poolAmountOut).toString())
    console.log({initialBalance: fromWei(initialBalance), finalBalance: fromWei(finalBalance)})
  })

  it('redeemExact', async function() {
    const reserve = _artifacts.reserves[0]
    const poolAmountIn = toBN(toWei('5'))
    await _artifacts.pool.approve(_artifacts.uniswap.address, poolAmountIn)

    const initialBalance = await _artifacts.pool.balanceOf(admin)
    const initialReserveBalance = await reserve.balanceOf(admin)
    const tokenAmountOut = await _artifacts.uniswap.redeemExact.call(poolAmountIn, reserve.address, 0, reserve.address)
    await _artifacts.uniswap.redeemExact(poolAmountIn, reserve.address, 0, reserve.address)
    const finalBalance = await _artifacts.pool.balanceOf(admin)
    const finalReserveBalance = await reserve.balanceOf(admin)
    assert.equal(finalBalance.toString(), initialBalance.sub(poolAmountIn).toString())
    assert.equal(finalReserveBalance.toString(), initialReserveBalance.add(tokenAmountOut).toString())
    console.log({initialBalance: fromWei(initialBalance), finalBalance: fromWei(finalBalance)})
  })

  it('redeemExact (tokenOut != reserveToken)', async function() {
    const tokenOut = await Reserve.new()
    const reserve = _artifacts.reserves[0]
    const poolAmountIn = toBN(toWei('5'))
    await _artifacts.pool.approve(_artifacts.uniswap.address, poolAmountIn)

    const initialPoolBalance = await _artifacts.pool.balanceOf(admin)
    const initialTokenOutBalance = await tokenOut.balanceOf(admin)

    const tokenAmountOut = await _artifacts.uniswap.redeemExact.call(poolAmountIn, tokenOut.address, 0, reserve.address)
    await _artifacts.uniswap.redeemExact(poolAmountIn, tokenOut.address, 0, reserve.address)

    const finalPoolBalance = await _artifacts.pool.balanceOf(admin)
    const finalTokenOutBalance = await tokenOut.balanceOf(admin)
    assert.equal(finalPoolBalance.toString(), initialPoolBalance.sub(poolAmountIn).toString())
    assert.equal(finalTokenOutBalance.toString(), initialTokenOutBalance.add(tokenAmountOut).toString())
    console.log({initialPoolBalance: fromWei(initialPoolBalance), finalPoolBalance: fromWei(finalPoolBalance)})
  })
})
