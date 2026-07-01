void main() { 
  print(Uri.parse('http://localhost:8080/api/v1').resolve('trainer/tasks')); 
  print(Uri.parse('http://localhost:8080/api/v1/').resolve('trainer/tasks'));
}
