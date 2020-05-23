const utils = require('../utils/utils')

contract("Core", accounts => {
  let _artifacts

  before(async function() {
    _artifacts = await utils.getArtifacts(artifacts)
  })

  it('rebalance', async function() {
    await _artifacts.core.reBalance()
  })
})
