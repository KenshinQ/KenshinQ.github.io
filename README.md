# KenshinQ.github.io
#coding:utf-8
import codecs
import os
import re
from os.path import getsize,splitext
import json
import shutil
#                      class    AAA :       {}
kclassRE = re.compile('class\s+(\w+)\s*:?\s*(.*?)\s*{(.*?)}',re.S)
publicDomainRE = re.compile('\s*public:\s*(.*?)',re.S)
funcRE = re.compile('\w+[\s\*&]+(\w+)\((.*?)\)')
staticFuncRE = re.compile('\s+static\s+\w+[\s\*&]+(\w+)\((.*?)\)')

def getData(file):
    text = codecs.open(file,"r","utf-8").read()
    text = re.sub(r"/\*[\S\s]*?\*/","",text)
    text = re.sub(r"//[^\t\n]*","",text)
    kclasses = kclassRE.findall(text)
    for kclass in kclasses:
        print kclass

cppDir = "Action"
if __name__=='__main__':
    current_dir = os.path.dirname(os.path.realpath(__file__))
    for file in os.listdir(current_dir):
        last = splitext(file)[1]
        if file=="GameCore.h":
            getData(os.path.join(cppDir,file))
