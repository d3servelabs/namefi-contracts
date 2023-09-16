// An ExpressJS to respond a SVG by URL

const express = require('express');
const app = express();
const ethers = require("ethers");
const dotenv = require('dotenv');
dotenv.config();
const infuraProvider = new ethers.providers.InfuraProvider(
  "sepolia",
  process.env.INFURA_API_KEY,
);

const abi = [
  "function tokenURI(uint256 tokenId) public view returns (string memory)",
  "function getExpiration(uint256 tokenId) public view returns (uint256)",
  "function isLocked(uint256 tokenId) public view returns (bool)",
  "function idToNormalizedDomainName(uint256 tokenId) public view returns (string memory)",
  "function normalizedDomainNameToId(string memory domainName) public pure returns (uint256)"
];

const contract = new ethers.Contract( process.env.D3BRIDGE_NFT_ADDRESS , abi , infuraProvider )
app.get('/svg/:domain/image.svg', (req, res) => {
  // get domain parameter from URL
    const domain = req.params.domain;
    const svgContent = 
    `<svg width="1024" height="1024" xmlns="http://www.w3.org/2000/svg" style="background-color: #000;">
        <rect width="100%" height="100%" fill="#222" />
        <text x="50%" y="40%" dominant-baseline="middle" text-anchor="middle" fill="#eee" font-size="60px">D3Bridge Deed</text>
        <text x="50%" y="60%" dominant-baseline="middle" text-anchor="middle" fill="#eee" font-size="100px">${domain}</text>
    </svg>`
    // respond with the content as SVG file
    res.set('Content-Type', 'image/svg+xml');
    res.send(svgContent);
});

app.get('/json/:domain', async (req, res) => {
    const domain = req.params.domain;
    let tokenId = await contract.normalizedDomainNameToId(domain);
    let expirationDate = await contract.getExpiration(tokenId);
    let isLocked = await contract.isLocked(tokenId);

    const jsonContent =

    {
      is_normalized: true,
      name: domain,
      description: `D3Bridge Deed of ${domain}`,
      attributes: [
        {
          trait_type: "Expiration Date",
          display_type: "date",
          value: expirationDate
        },
        {
          trait_type: "Is Locked",
          display_type: "bool",
          value: isLocked
        }
      ],
      url: `https://bridge.d3dev.xyz/domain/${domain}`,
      version: 0,
      background_image: `https://meta.bridge.d3dev.xyz/svg/${domain}/image.svg`,
      image: `https://meta.bridge.d3dev.xyz/svg/${domain}/image.svg`,
      image_url: `https://meta.bridge.d3dev.xyz/svg/${domain}/image.svg`
    };

    // respond with the content as json
    res.set('Content-Type', 'application/json');
    res.send(JSON.stringify(jsonContent, null, 2));
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});
