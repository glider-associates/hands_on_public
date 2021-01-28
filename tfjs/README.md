# learn tsjs 1

## ENV
```
nodenv install 10.14.2
npm install
```

## require
```
const tf = require('@tensorflow/tfjs-node');
```

## Tensor


```
let t1 = tf.tensor1d([0,1,2,3,4,5,6,7,8,9]);
t1.print();
t1.slice(0, 3).print();
t1.slice(5).print();
t1.arraySync();

let t2 = tf.tensor2d([0,1,2,3,4,5,6,7,8,9], [5, 2]);
t2.print();

t1.reshape([5,2]).print();
```

### One-Hot
XOR

```
[0, 0] => [1]
[1, 0] => [0]
[0, 1] => [0]
[1, 1] => [1]

```

この出力側をOneHotにするとこうなる。

```
[0, 0] => [0, 1]
[1, 0] => [1, 0]
[0, 1] => [1, 0]
[1, 1] => [0, 1]

```


### Q1 1dデータ

```
let inputs = tf.tensor2d([0,0,0,1,1,0,1,1], [4,2]);
let outputs = ...

```

### Q2 2d(one-hot)データ

```
let inputs = tf.tensor2d([0,0,0,1,1,0,1,1], [4,2]);
let outputs = ...

```

## Model
```
let model = tf.sequential();
model.add(tf.layers.dense({inputShape: [2], units: 64, activation: 'relu', useBias: true}));
model.add(tf.layers.dense({units: 1, activation: 'sigmoid'}));
model.compile({
  optimizer: tf.train.adam(0.005),
  loss: 'meanSquaredError',
  metrics: ['mse'],
});

```

```
input         hidden             output
[x, y] --+-- [h1a, h1b] ---+--- [o]
         |                 |
         +-- (h2a, h2b) ---+
         |                 |
         :                 :
         +- (h64a, h64b) --+

```

### activations
 https://ja.wikipedia.org/wiki/%E6%B4%BB%E6%80%A7%E5%8C%96%E9%96%A2%E6%95%B0

 - relu ランプ関数。大体にコレで良い
 - sigmoid 古典的
 - softmax 正規化(cosは保持されない)

### optimizer

 - adam 確率的勾配降下法。大体これでいい。
 - adamax adamの変形。使い分けるものだがよく判らん。
 - rmsprop 勾配の二乗の移動（割引）平均を維持する。勾配をこの平均値のルートで割る。偽ピークを踏み越え易い。

### loss(損失関数)

 - meanSquaredError 平均2乗誤差
 - binaryCrossentropy 真のラベルと予測ラベル
 - categoricalCrossentropy ラベルと予測値。使い分け方が判らん

## Fit

```
model.fit(inputs, outputs, {
  batchSize: 32,
  epochs: 100,
  stepsPerEpoch: 1,
  shuffle: true,
  callbacks: {
    onEpochEnd: (i, e) => {
      console.log('****', i, e)
    }
  }
});


```

### result
```
console.log(model.predict(inputs).arraySync())
```

### Q3
outputsをOne-hotにして、softmaxでfitさせる。

## tfjs-vis
index.html
