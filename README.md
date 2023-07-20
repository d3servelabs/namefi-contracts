# Donkey Decay NFT

## Price time decay

$P = P_{initial} \left(\frac{P_{final}}{P_{initial}}\right)^{\frac{B}{B_{total}}}$

$P = \frac{P_{initial} \left(\frac{P_{final}}{P_{initial}}\right)^{\frac{B \cdot s}{B_{total} \cdot s}}}{s}$

## Installing dependencies

```
npm install
```

## Testing the contract

```
npm test
```

## Deploying the contract

You can target any network from your Hardhat config using:

```
npx hardhat run --network <network-name> scripts/deploy.ts
```
