const typedMessage = {
  primaryType: 'DnsUpdateRequest',
  domain: {
    name: 'D3Bridge',
    version: '1',
  },

  types: {
    EIP712Domain: [
      { name: 'name', type: 'string' },
      { name: 'version', type: 'string' },
      { name: 'chainId', type: 'uint256' },
      { name: 'verifyingContract', type: 'address' },
    ],
    DnsUpdateRequest: [
      { name: 'updateType', type: 'string' },
      { name: 'record', type: 'DnsRecord' },
    ],
    DnsRecord: [
      { name: 'name', type: 'string' },
      { name: 'dnsType', type: 'string' },
      { name: 'value', type: 'string' },
      { name: 'ttl', type: 'uint256' },
    ],
   },
  message: {
    updateType: "ADD",
    record: {
      name: "test-alice.test.d3dev.xyz",
      dnsType: "A",
      value: "1.2.3.4",
      ttl: 300
    }
  }
};

module.exports = typedMessage;
