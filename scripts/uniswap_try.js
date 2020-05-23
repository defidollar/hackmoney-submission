const IUniswap = artifacts.require("IUniswap");
const Reserve = artifacts.require('Reserve');

const MAX = web3.utils.toTwosComplement(-1);

async function execute() {
  const accounts = await web3.eth.getAccounts()
  const uniswap = await IUniswap.at('0xf164fC0Ec4E93095b804a4795bBe1e041497b92a');

  // const mkr = await Reserve.at('0x61e4CAE3DA7FD189e52a4879C7B8067D7C2Cc0FA')
  // const tusd = await Reserve.at('0x1c4a937d171752e1313D70fb16Ae2ea02f86303e')
  // await tusd.approve(uniswap.address, MAX)
  const tokenAmountIn = web3.utils.toWei('2')
  // MKR, DAI
  let path = ['0x61e4CAE3DA7FD189e52a4879C7B8067D7C2Cc0FA', '0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD']
  let amounts = await uniswap.getAmountsOut(tokenAmountIn, path)
  // let amounts = await uniswap.swapExactTokensForTokens.call(
  //   tokenAmountIn,
  //   0,
  //   // MKR, DAI
  //   ['0x61e4CAE3DA7FD189e52a4879C7B8067D7C2Cc0FA', '0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD'],
  //   accounts[0],
  //   MAX
  // )
  amounts.forEach(a => {
    console.log(web3.utils.fromWei(a.toString()))
  })

  // amounts = await uniswap.swapExactTokensForTokens.call(
  //   tokenAmountIn,
  //   0,
  //   // MKR, TUSD
  //   ['0x61e4CAE3DA7FD189e52a4879C7B8067D7C2Cc0FA', '0x1c4a937d171752e1313D70fb16Ae2ea02f86303e'],
  //   accounts[0],
  //   MAX
  // )
  // amounts.forEach(a => {
  //   console.log(web3.utils.fromWei(a.toString()))
  // })
}

module.exports = async function (callback) {
  try {
    await execute()
  } catch (e) {
    // truffle exec <script> doesn't throw errors, so handling it in a verbose manner here
    console.log(e)
  }
  callback()
}
