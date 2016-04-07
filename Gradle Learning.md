##学习Gradle
*Gradle是一个新的构建工具，使用Groovy语言来作为构建任务的描述语言。*

####一、Groovy语言基础
- Groovy是在java的基础上扩展出来的脚本语言，完美兼容java的语法，同时它又带来了脚本语言如python、ruby等语言的特性。
- Groovy支持动态类型，定义变量的时候不需要指定变量类型。定义变量的关键字是def。
- Groovy定义函数时，参数也不需要类型。函数的最后一行代码的结果被作为函数的返回值返回。
- Groovy像python中一样支持单引号、双引号和三引号来包围字符串。但是，这三种方式分别有自己的特点，在使用单引号‘’来包围字符串时，不对$符 号进行转义，原样输出；而在使用双引号“”来包围字符串时，会对跟随在$符号后面的表达式进行求值替换；而使用三引号‘“’”包围字符串时，则可以随意换行。
- Groovy引入了一种新的对象类型---闭包。闭包的定义的结构是{params->code body}.  如果在定义闭包的时候没有定义参数params，则会有一个默认参数it。当调用的函数的最后一个参数是闭包的时候，可以省略掉函数调用时包围参数的圆括号。
- Groovy可以定义类，而Groovy中不是定义在类中的代码则为脚本代码，而Groovy脚本是最终是会被编译为一个Java类的，脚本中定义的函数为这个脚本类的方法，同时这个脚本类会生成一个main函数和一个run方法，当直接执行脚本文件的时候，jvm会用这个main函数作为入口，创建脚本类的对象，然后
执行对象的run方法。脚本文件中的脚本代码，如果不是函数定义，则都在run方法中执行。所以会出现脚本中函数直接方法函数外部的脚本定义的变量会
报错，这就是因为上面提到的原理，导致执行函数的时候，是找不到变量定义的。而要为脚本类添加一个属性，使得脚本对象的函数可以随时访问的话，需要引入Field概念，即通过import groovy.transform.Field后，使用@Field关键字来声明变量，这样这个变量就会在脚本被编译成脚本类的时候，变量成为脚本类的属性，于是脚本对象的方法可以随时访问这个变量。
###二、Gradle介绍及使用
- Gradle是一个工具，其本质是一个编程框架，所有的工作是通过各种Gradle api的使用来完成工作。
- 使用Gradle来编译一个待编译的工程都叫一个projcet,而每一个project在的构建包含一系列的Task，而编译一个project包含多少个task，是由编译脚本指定的插件决定的。插件是什么呢？插件是用来定义task，并执行task的东西。
- Gradle作为一个框架，负责定义流程和规则，而具体的编译工作则由具体的插件来完成。比如编译Java有java插件，编译android app有android app插件，编译android library有android library 插件。每一个project对应一个build.gradle脚本文件，Gradle支持多project一起构建，当要多project一起构建的时候，需要在根project目录添加一个settings.gradle文件来指定要一起构建的工程。

####二、Gradle的工作流程是：
1. 初始化阶段，这个时候如果有settings.gradle，则会执行settings.gradle
2. 配置阶段，这个时候每个project的build.gradle都会被解析，以建立任务的有向图，确定执行过程中任务的依赖关系
3. 执行阶段，你在执行命令gradle xxx，xxx指定的任务链上的所有任务全部会按依赖关系执行一遍。因为Gradle是基于Groovy的，所以Gradle脚本在执行的时候也会被转换为java类对象。
4. Gradle中主要有三类对象：
  - Gradle对象，当我们在执行gradle xxx的时候，gradle会从默认的配置脚本中构造出一个Gradle对象，在构建执行过程中，只有一个Gradle对象。
  - Project对象，每一个build.gradle会被转换为一个Project对象。
  - Settings对象，每一个settings.gradle会被转换为一个Settings对象。
  - 而其他的gradle文件，除非是定义的class，否则一般都是转换成一个实现了Script接口的对象，和Groovy脚本差不多。
5. Gradle中有一个额外属性的概念（extra property）， 可以通过在第一次定义或使用某一个属性的时候，加一个ext前缀来标识它是一个额外属性，这样
就会为对象增加一个额外的属性，以后可以随便访问使用这个额外属性，并且不需要ext前缀。Project对象和Gradle对象支持额外属性的特性。定义
额外属性有两种方式，一种方式是 对象.ext.属性名=value，另一种是对象.ext{属性名 = value}。
Groovy中脚本类对象会有一个delegate属性，所以Gradle中，其他gradle脚本文件转换生成的脚本类对象都会有一个delegate属性，而在Gradle中，如果
在脚本对象中找不到变量或函数的时候，就会去它的delegate对象中去找，而在build.gradle中通过apply加载的gradle脚本时，会把这个脚本转换为
脚本对象，并且，默认设置它的delegate属性为加载它的project对象。
6. Gradle中的Project对象有一些预置的script block脚本块，通常构建的配置都在这些脚本块中进行，这些脚本块的本质呢，基本上就是闭包代码。
有一些常见的script block需要熟悉：
  - allprojects{}----用来配置当前project和所有子project
  - artifacts{}------用来配置当project的结果输出
  - buildscript{}----用来配置当前project的编译脚本的classpath
  - configuration{}--当前project的依赖设置
  - dependencies{}---当前project的依赖
  - repositories{}---当前project的远程库
  - sourceSets{}-----当前project的工程文件
  - subprojects{}----当前project的子project
  - publishing{}-----编译输出拓展
####三、Gradle Wrapper使用
  *使用Gradle Wrapper来构建，可以使得构建的开发人员，不用提前安装好Gradle也可以正常构建，而且，可以避免不同的开放人员在各自的机子上安装的Gradle版本不同，而导致构建出现问题。使用Gradle Wrapper可以用来保证工程的构建始终使用统一的Gradle版本来构建工程。*
- 可以通过在工程的根目录上执行gradle wrapper命令来执行wrapper任务，会为使用gradle wrapper编译生成必要的文件，只需要执行一次就可以。
  wrapper任务是始终可以执行的，当执行这个命令时可以通过--gradle-version来指定gralde wrapper使用的gradle版本，如果不指定，则会生成指
  向当前执行环境中gradle版本的gradle wrapper。
- gradle/wrapper/gradle-wrapper.properties文件中可以配置需要使用的Gradle的版本的下载地址。
- 通过Gradle wrapper来指定特定版本的Gradle，构建的时候，如果本地没有wrapper指定的版本的Gradle，会主动去下载对应的Gradle版本。
- 配置好Gradle wrapper以后，接下来的构建任务都使用gradlew xxx来执行
