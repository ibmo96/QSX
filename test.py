import sys
import re

#def test_file_stuff(file):
 #	with open(file) as f:
		#print(f.readlines())
		#list = f.readlines() 
		#print(list)
		#print(list[-1])
		#test_list = ['string one\n','string two\n']
		#list[-1:-1] = test_list
		#print(list)
	#if f.readlines()[-1].contains('/n'): 
		#print('true')

def test_re(s): 
	res = re.search('server_name(.*);', s)
	#print(res.group(1))
	res.group

def test_string_extract(s):
	start = 'server_name'
	end = ';'

	print[s.find(start)+len(start):s.rfind(end)]



def main():
	#test_string_extract('server_name    www.example.com;')
	test_re('server_name    www.example.com;')
main()
