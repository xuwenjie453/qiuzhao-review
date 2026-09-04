### DeepLearning-002-001 | ★★★★☆

对比BERT、OpenAI GPT、ELMo架构之间的差异。

**答案：**
ELMo是双向LSTM特征提取器；GPT是Transformer decoder单向自回归；BERT是Transformer encoder双向注意力，用MLM预训练。


### DeepLearning-002-002 | ★★★★☆

Word2Vec中为什么使用负采样（negative sample）？

**答案：**
softmax要除以全词表的概率和（数万词），每步代价太大；负采样把多分类转化为中心词与正例/若干负例的二分类logistic损失，每步只需更新k+2个词向量，效率大幅提升；负例按unigram^0.75频率采样，还能平滑高频词、改善低频词表示。


### DeepLearning-002-003 | ★★★★☆

word2vec相比之前的Word Embedding方法好在什么地方？

**答案：**
此前的表示（one-hot、LSA、NNLM副产品）要么稀疏高维无语义，要么难扩展；Word2Vec用浅层网络（CBOW/Skip-gram+层次softmax/负采样）在海量纯文本上高效训练出50~300维稠密词向量，能表达语义线性关系（king-man+woman≈queen），训练快、语料规模几乎不受限。


### DeepLearning-002-004 | ★★★★★

讲讲对Attention的理解？

**答案：**
Attention是按相关性动态加权聚合信息的机制：Query与各Key算相似度，经softmax归一化为权重后对Value加权求和。本质是可微分的软寻址/检索，打破了固定长度向量的信息瓶颈，支持长程依赖建模，权重还可视化解释；Transformer中Q/K/V由输入线性投影得到，缩放点积并行计算。


### DeepLearning-002-005 | ★★★★★

Attention机制和传统的Seq2Seq模型有什么区别？

**答案：**
传统Seq2Seq把整句压缩成固定长度向量，长句信息丢失严重且解码每步用同一向量；Attention让解码每步自适应地从编码器全部隐状态中加权选取相关信息，消除信息瓶颈、缓解长距离依赖，并提供软对齐可解释性。Attention是对Seq2Seq的增强组件，Transformer则完全弃用循环、纯靠attention。


### DeepLearning-002-006 | ★★★★☆

self-attention和target-attention的区别？

**答案：**
self-attention的Q、K、V来自同一序列，计算序列内部元素间的相关性，建模内部依赖（如Transformer编码器）；target-attention以外部目标为Query（如推荐中候选item、解码器当前状态）去注意序列的K/V，刻画"目标与历史序列的相关性"，典型如DIN、decoder对encoder的cross-attention。


### DeepLearning-002-007 | ★★★★☆

在常规attention中，一般有k=v，那self-attention可以吗？

**答案：**
可以。self-attention本身就是K=V的特例（K、V来自同一序列，可用不同投影矩阵，甚至共享参数，如ALBERT的KV共享）。通常三者来源和投影都可不同（cross-attention中Q来自解码器、K/V来自编码器），K=V只表示来源相同，不要求是同一矩阵。


### DeepLearning-002-008 | ★★★★☆

目前主流的attention方法有哪些？

**答案：**
按计算形式：加性attention、缩放点积attention（主流）、双线性attention；按结构：Multi-Head、跨注意力、稀疏注意力（Longformer/BigBird）、线性注意力（Performer、Linformer）、FlashAttention（IO感知的精确加速）、MQA/GQA（推理KV缓存优化）。核心思想都是Q-K相似度加权V。


### DeepLearning-002-009 | ★★★★☆

self-attention在计算的过程中，如何对padding位做mask？

**答案：**
padding位置的attention score置为负无穷（如-1000）后再softmax，使$e^{-\infty}=0$，注意不能置0因为$e^0=1$。


### DeepLearning-002-010 | ★★★★☆

深度学习中attention与全连接层的区别何在？

**答案：**
全连接层的权重是静态参数、与输入内容无关，对每个位置独立做线性变换；attention的权重由输入动态计算（数据驱动、随样本变化），作用在"元素间关系"上，对Value加权求和。attention具备排列等变性（需配位置编码）、全局感受野，参数量与序列长度无关。


### DeepLearning-002-011 | ★★★★★

Transformer为何使用多头注意力机制？（为什么不使用一个头）

**答案：**
多头保证transformer可以注意到不同子空间的信息，捕捉更丰富的特征信息，可类比CNN中同时使用多个滤波器的作用。


### DeepLearning-002-012 | ★★★★★

Transformer为什么Q和K使用不同的权重矩阵生成，为何不能使用同一个值进行自身的点乘？

**答案：**
Q/K使用不同投影矩阵可保证在不同空间进行投影，增强表达能力；若Q=K，得到的attention矩阵类似单位矩阵，self-attention退化为point-wise线性映射。


### DeepLearning-002-013 | ★★★★★

Transformer计算attention的时候为何选择点乘而不是加法？两者计算复杂度和效果上有什么区别？

**答案：**
点乘可得到attention score矩阵对V提纯，且可并行加速；加法整体计算量与点积相似，效果与dk相关，dk越大加法效果越显著。


### DeepLearning-002-014 | ★★★★☆

为什么在进行softmax之前需要对attention进行scaled（为什么除以dk的平方根）？请用公式推导讲解。

**答案：**
若softmax内数值数量级太大会输出近似one-hot形式导致梯度消失；假设q、k各分量独立同分布均值0方差1，则qk点积方差为dk，除以sqrt(dk)可将方差控制在1，使softmax更平滑。


### DeepLearning-002-015 | ★★★★☆

在计算attention score的时候如何对padding做mask操作？

**答案：**
padding位置置为负无穷而不是0，因为softmax时e^0=1会导致计算错误，而e^-inf=0。


### DeepLearning-002-016 | ★★★★★

为什么在进行多头注意力的时候需要对每个head进行降维？

**答案：**
将原有的高维空间转化为多个低维空间再拼接形成同样维度的输出，借此丰富特征信息。


### DeepLearning-002-017 | ★★★★☆

为何在获取输入词向量之后需要对矩阵乘以embedding size的开方？意义是什么？

**答案：**
embedding matrix用xavier初始化，方差是1/embedding size，乘以embedding size的开方使embedding matrix方差为1，有利于收敛。


### DeepLearning-002-018 | ★★★★★

简单介绍一下Transformer的位置编码？有什么意义和优缺点？

**答案：**
self-attention是位置无关的，需要位置编码表达token位置信息；原始Transformer使用固定的正弦位置编码表示绝对位置信息。


### DeepLearning-002-019 | ★★★★☆

你还了解哪些关于位置编码的技术，各自的优缺点是什么？

**答案：**
如相对位置编码RPE（计算attention score时加入可训练的相对位置参数）、复数域函数表示等。


### DeepLearning-002-020 | ★★★★★

简单讲一下Transformer中的残差结构以及意义。

**答案：**
每个子层使用output = LayerNorm(x + SubLayer(x))的残差连接；反向传播时梯度有"1"保底缓解梯度消失，网络只需学习残差降低优化难度，底层特征经跳跃连接直达高层。


### DeepLearning-002-021 | ★★★★★

为什么transformer块使用LayerNorm而不是BatchNorm？LayerNorm在Transformer的位置是哪里？

**答案：**
NLP中句子长度不一致且各batch信息没什么关系，因此只考虑句子内信息的归一化即LN；LN位于每个子层残差连接之后（Post-LN）或之前（Pre-LN）。


### DeepLearning-002-022 | ★★★★☆

简答讲一下BatchNorm技术，以及它的优缺点。

**答案：**
优点：缓解内部协变量偏移、使损失平面更平滑加快收敛、缓解梯度饱和问题；缺点：依赖batch size、对序列长度不一致的NLP数据不友好。


### DeepLearning-002-023 | ★★★★★

Transformer的点积模型做缩放的原因是什么？

**答案：**
防止点积结果数量级过大导致softmax梯度消失，除以sqrt(dk)使方差稳定为1。


### DeepLearning-002-024 | ★★★★☆

BERT用字粒度和词粒度的优缺点有哪些？

**答案：**
字粒度（中文BERT默认）：词表小、无OOV、泛化好，但序列长、计算开销大，单字语义弱需模型自行组词；词粒度：序列短、词语义完整，但词表庞大、OOV严重、分词错误会传播且引入切分歧义。英文WordPiece/BPE子词粒度是两者折中。


### DeepLearning-002-025 | ★★★★☆

BERT的Encoder与Decoder掩码有什么区别？

**答案：**
Encoder是双向self-attention，不加因果掩码（只有padding mask），每个token可见全句，适合理解任务；Decoder加下三角因果掩码（look-ahead mask），每个位置只能看到自己及之前的token，防止训练时看到未来，保证自回归生成的一致性。


### DeepLearning-002-026 | ★★★★☆

BERT用的是transformer里面的encoder还是decoder？

**答案：**
encoder（双向注意力，只用Transformer的编码器堆叠）。


### DeepLearning-002-027 | ★★★★☆

为什么BERT选择mask掉15%这个比例的词，可以是其他的比例吗？

**答案：**
15%是"训练信号量"与"预训练-微调分布一致性"的折中：比例太低，每句可供学习的token太少、收敛慢、数据利用率低；太高，下游微调见的是完整文本而预训练输入大量[MASK]/替换词，分布不一致加剧。这是经验值而非理论最优，可调整（后续工作有不同比例与更优的替换策略），8%~20%内差别不大。


### DeepLearning-002-028 | ★★★★☆

为什么BERT在第一句前会加一个[CLS]标志？

**答案：**
[CLS]无语义，经过双向注意力后聚合整句信息，可用于下游分类任务。


### DeepLearning-002-029 | ★★★★☆

BERT非线性的来源在哪里？

**答案：**
主要来自每层FFN中的激活函数（原版BERT用GELU），多层堆叠赋予模型非线性表达能力；此外softmax的非线性与LayerNorm也贡献非线性——self-attention本身的加权求和对输入是线性的。


### DeepLearning-002-030 | ★★★★☆

BERT训练时使用的学习率warm-up策略是怎样的？为什么要这么做？

**答案：**
BERT采用线性warm-up：峰值学习率很小（如1e-4量级，fine-tune常用2e-5~5e-5），训练最初约前10% steps内从0/极小值线性升到峰值，之后线性衰减。原因：初期参数随机、梯度大且不稳定，Adam二阶矩估计在初期不准，大学习率易导致发散；warm-up先平稳探索再大步收敛。


### DeepLearning-002-031 | ★★★★☆

在BERT应用中，如何解决长文本问题（输入超过512）？

**答案：**
常用方案：滑动窗口切块分别编码后聚合（池化）；截断策略（取头尾拼接）；层次化编码（先块级BERT再上层模型融合）；换用长文本模型（Longformer、BigBird稀疏注意力、RoFormer/RoPE等）；或先抽取关键句/摘要压缩输入。工程上也可用检索只取与任务相关的段落。


### DeepLearning-002-032 | ★★★★☆

BN、LN、IN、GN的区别是什么？

**答案：**
区别在统计量的计算维度：BN对每个通道沿batch和空间维归一化，适合CV大batch，batch小则不稳；LN对单样本所有通道归一化，与batch无关，适合NLP/Transformer；IN对单样本每通道内部归一化，适合风格化生成任务；GN把通道分组、在样本内按组归一化，是batch小时的CV折中方案。


### DeepLearning-002-033 | ★★★★☆

RMS Norm和Layer Norm的区别是什么？

**答案：**
RMS Norm去掉了减去均值的部分，只用均方根缩放，计算更快，LLaMA等模型采用。


### DeepLearning-002-034 | ★★★★☆

Post-LN和Pre-LN的区别是什么？

**答案：**
Post-LN（原Transformer/BERT）：LN在残差相加之后，深层网络梯度不稳定、需warm-up，但训练充分后通常效果略好；Pre-LN（GPT-2起多数大模型）：LN放在子层内、残差主通路外，梯度可经恒等映射直达底层，深层训练更稳定、对warm-up依赖小，但表示能力略受限，通常加final LayerNorm弥补。


### DeepLearning-002-035 | ★★★★☆

BERT预训练还需要对attention做mask吗？

**答案：**
需要。MLM是双向语言模型，不需要因果掩码，但必须有padding mask屏蔽batch内变长序列的填充token，防止注意力作用于无效位置。另外MLM的15%选中位置中只有80%换成[MASK]、10%随机替换、10%保留原词，这是有意设计，无需额外mask。


### DeepLearning-002-036 | ★★★★☆

前置层归一化（Pre-LN）的好处是什么？

**答案：**
Pre-LN梯度更稳定，训练更平稳，不易发散，可省去warm-up；但表达能力略弱于Post-LN。


### DeepLearning-002-037 | ★★★★☆

层归一化为什么用RMSNorm而不是LayerNorm？

**答案：**
RMSNorm去掉减均值操作，只做均方根缩放，计算量更小、训练更快，效果与LN相当。


### DeepLearning-002-038 | ★★★★☆

BERT是怎么实现看到上下文（双向编码）的？

**答案：**
BERT用Transformer encoder的双向自注意力，每个token能同时看到左右两侧上下文。


### DeepLearning-002-039 | ★★★★☆

写出sigmoid函数及其一阶导数。

**答案：**
sigmoid(x)=1/(1+e^-x)，导数为f(x)(1-f(x))。


### DeepLearning-002-040 | ★★★★☆

attention计算中一定要除以sqrt(dk)吗，可以是别的数吗？

**答案：**
不是必须，但缩放是必要的：Q·K内积的方差随维度dk线性增大，不缩放会使softmax落入饱和区、梯度趋零、注意力变one-hot。除以sqrt(dk)恰好把独立同分布假设下的内积方差归一为1；理论上可除以真实标准差或用可学习温度系数（如部分工作），但sqrt(dk)是该假设下最合理的默认值。


### DeepLearning-002-041 | ★★★★☆

Word2Vec的两种实现（CBOW和Skip-gram）分别是什么？哪个更好？

**答案：**
CBOW用上下文词（向量平均/拼接）预测中心词，训练快、对高频词平滑效果好；Skip-gram用中心词预测每个上下文词，训练信号更多，对小语料和低频词效果更好。追求速度和大语料选CBOW，重视低频词语义或语料小选Skip-gram。


### DeepLearning-002-042 | ★★★★☆

Word2Vec负采样是怎么实现的？

**答案：**
对每个正样本对(中心词c, 上下文词o)，从噪声分布Pn(w)∝count(w)^0.75采样k个负例n_i，最小化损失 -log σ(v_o·u_c) - Σ log σ(-v_{n_i}·u_c)，即1正k负的二分类logistic；每步只需更新正负例涉及的k+2个词向量，负例采样时高频词可做子采样。


### DeepLearning-002-043 | ★★★★☆

Word2Vec的softmax损失和负采样用的损失，本质上是否一样？

**答案：**
不完全一样。softmax交叉熵是精确的多分类最大似然，分母含全词表；负采样是用少量负例对softmax目标做近似（NCE的简化版），两者优化方向一致——提升正例对概率、压低其他词概率——但负采样是有偏近似，只是经验上效果相当且快得多。


### DeepLearning-002-044 | ★★★★★

Transformer编码器的位置编码用的是什么函数？解码器和编码器的不同之处是什么？解码器的mask是怎么设计的？

**答案：**
原始Transformer用正弦/余弦函数的固定位置编码；解码器多了cross-attention和带因果mask的多头注意力（叠加padding mask）。


### DeepLearning-002-045 | ★★★★☆

BERT和T5的区别是什么？

**答案：**
BERT是encoder-only双向模型，用MLM+NSP预训练，输出需接任务头，擅长理解类任务；T5是encoder-decoder架构，把一切任务统一为text-to-text格式，用span corruption（遮住连续片段由decoder自回归生成）+多任务混合预训练，天然支持生成与多任务迁移。


### DeepLearning-002-046 | ★★★★☆

BERT的参数量怎么计算？

**答案：**
每层≈注意力4H²（Q/K/V/O投影）+FFN 8H²（H×4H与4H×H两个矩阵）≈12H²。BERT-base：12层×12×768²≈85M，加embedding（词表30522×768≈23.4M、position 512×768、segment 2×768）和pooler 768²，总计≈110M；BERT-large：24层×12×1024²≈302M，加embedding≈340M。


### DeepLearning-002-047 | ★★★★☆

RoBERTa相比BERT做了哪些改进？

**答案：**
去掉NSP任务、动态mask、更大batch和更多数据、更长的训练时间、用Byte-level BPE。


### DeepLearning-002-048 | ★★★★☆

讲一下你对知识蒸馏的了解。

**答案：**
知识蒸馏让小模型（student）模仿大模型（teacher）：用带温度T的softmax得到软标签（温度升高使分布更平滑，蕴含类间相似度的"暗知识"），损失=KL(teacher||student)×T²+与真实标签的交叉熵加权。还可蒸馏中间特征（fitnet/hint）和注意力关系；用于模型压缩、集成蒸馏与自蒸馏。


### DeepLearning-002-049 | ★★★★☆

BERT的position embedding是怎么做的？

**答案：**
BERT使用可学习的绝对位置 embedding，与token embedding相加。


### DeepLearning-002-050 | ★★★★☆

BERT是怎么做预训练的？预训练之后下游任务有哪些？

**答案：**
MLM（随机mask 15%预测）+NSP（下一句预测）；下游有分类、序列标注（NER）、句对任务、问答抽取等。


### DeepLearning-002-051 | ★★★★☆

词表很大时，如何优化隐层到输出Softmax层的计算量？

**答案：**
可用层次softmax、负采样（word2vec）、自适应softmax或boundedin softmax等。


### DeepLearning-002-052 | ★★★★★

Transformer encoder中的信息是怎么用到decoder中的？

**答案：**
通过cross-attention，decoder每层以encoder输出作为K/V。


### DeepLearning-002-053 | ★★★★☆

BERT模型中文本转化为token id的整个过程是怎样的？

**答案：**
文本→Unicode规范化与清洗→按WordPiece分词（对英文按最长匹配切成词表子词，续词加##前缀；中文按字）→插入[CLS]、[SEP]（句对再加[SEP]与segment id 0/1）→查词表映射为token id→配合position embedding与segment embedding、超过512截断、batch内padding并生成attention mask。


### DeepLearning-002-054 | ★★★★☆

BN和Dropout共同使用时会出现什么问题？

**答案：**
Dropout使训练时激活的均值/方差随每批随机掩码波动，BN的batch统计量与测试时的滑动统计产生不一致（variance shift），两者叠加会放大训练/测试差异，导致性能下降。缓解：调整BN与Dropout的相对位置、改用Gaussian dropout并做方差校正，或用GN/LN替代BN。


### DeepLearning-002-055 | ★★★★☆

随机梯度下降和批量梯度下降的区别是什么？各有什么优缺点？

**答案：**
批量梯度下降（BGD）用全部样本算梯度：方向准确、收敛稳定，但每步开销大、内存高、不能在线更新；SGD用单样本或mini-batch：更新快、支持在线与大数据，噪声还有助于逃离鞍点/局部极小并起正则作用，但路径震荡、需学习率衰减。实践主流是mini-batch SGD折中。


### DeepLearning-002-056 | ★★★★☆

梯度下降法和牛顿法能保证找到函数的极小值点吗？为什么？

**答案：**
不能保证。梯度下降是迭代法，只能收敛到梯度为零的驻点：凸函数可到全局最优，非凸时依赖初始化和学习率，可能停在局部极小或鞍点附近；牛顿法收敛快，但Hessian不正定时可能收敛到鞍点甚至极大值（需线搜索或正则化修正），同样只在凸（或近似凸）条件下有全局保证。梯度为零只是极值的必要条件。


### DeepLearning-002-057 | ★★★★☆

什么是机器学习中的对比学习？

**答案：**
对比学习是一种表示学习范式：对同一样本施加两次不同数据增广构成正样本对，与batch内/记忆库中其他样本构成负样本对，用InfoNCE等对比损失训练编码器使正对相似、负对远离。代表工作SimCLR（大batch+投影头）、MoCo（动量编码器+负样本队列）；学到的表征可迁移到分类、检索等下游任务。


### DeepLearning-002-058 | ★★★★☆

介绍一下PyTorch中.detach()、.clone()、requires_grad=True、torch.no_grad()的原理与作用。

**答案：**
.detach()返回与原张量共享存储但脱离计算图的新张量，停止梯度追踪（常用于冻结部分网络或取出值）；.clone()复制数据生成不共享内存的新张量，若原张量requires_grad则克隆仍在图中；requires_grad=True标记张量为需要求导（可训练叶节点）；torch.no_grad()上下文内不建计算图、省显存，用于推理评估。典型组合：先detach()再clone()以安全修改参数副本。

