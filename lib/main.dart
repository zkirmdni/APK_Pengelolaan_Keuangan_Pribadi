import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'auth_service.dart';
import 'database_helper.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AuthService().isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        } else {
          bool isLoggedIn = snapshot.data as bool;
          return MaterialApp(
            home: isLoggedIn ? HomePage() : LoginPage(),
          );
        }
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String username = '';
  String password = '';
  final AuthService authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Username'),
                validator: (value) => value!.isEmpty ? 'Enter username' : null,
                onSaved: (value) => username = value!,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Enter password' : null,
                onSaved: (value) => password = value!,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text('Login'),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    bool success = await authService.login(username, password);
                    if (success) {
                      Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (context) => HomePage()));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Invalid credentials'),
                      ));
                    }
                  }
                },
              ),
              TextButton(
                child: Text('Create Account'),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterPage()));
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  String username = '';
  String password = '';
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Username'),
                validator: (value) => value!.isEmpty ? 'Enter username' : null,
                onSaved: (value) => username = value!,
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Enter password' : null,
                onSaved: (value) => password = value!,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text('Register'),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    try {
                      await dbHelper.createUser(username, password);
                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Username already exists'),
                      ));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Transaction> transactions = [];
  Map<String, double> budget = {};

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void deleteTransaction(int index) {
    setState(() {
      transactions.removeAt(index);
      saveData(); // Simpan perubahan setelah menghapus
    });
  }

  void editBudget(String category, double newAmount) {
    setState(() {
      budget[category] = newAmount; // Perbarui nilai budget
      saveData(); // Simpan perubahan ke SharedPreferences
    });
  }

  void deleteBudget(String category) {
    setState(() {
      budget.remove(category); // Hapus kategori dari map
      saveData(); // Simpan perubahan ke SharedPreferences
    });
  }

  void editTransaction(int index, Transaction updatedTransaction) {
    setState(() {
      transactions[index] = updatedTransaction;
      saveData(); // Simpan perubahan setelah mengedit
    });
  }

  void loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      transactions = (json.decode(prefs.getString('transactions') ?? '[]') as List)
          .map((item) => Transaction.fromJson(item))
          .toList();
      budget = Map<String, double>.from(json.decode(prefs.getString('budget') ?? '{}'));
    });
  }

  void saveData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('transactions', json.encode(transactions));
    await prefs.setString('budget', json.encode(budget));
  }

  void addTransaction(Transaction transaction) {
    setState(() {
      transactions.add(transaction);
      saveData();
    });
  }

  void setBudget(String category, double amount) {
    setState(() {
      budget[category] = amount;
      saveData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Personal Finance App'),
          actions: [
            IconButton(
              icon: Icon(Icons.logout),
              onPressed: () async {
                await AuthService().logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list), text: 'Transactions'),
              Tab(icon: Icon(Icons.pie_chart), text: 'Expense Chart'),
              Tab(icon: Icon(Icons.show_chart), text: 'Income Chart'),
              Tab(icon: Icon(Icons.account_balance_wallet), text: 'Budget'),
              Tab(icon: Icon(Icons.bar_chart), text: 'Monthly Report'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            TransactionList(
              transactions: transactions,
              deleteTransaction: deleteTransaction,
              editTransaction: editTransaction,
            ),
            ExpenseChart(transactions: transactions),
            IncomeChart(transactions: transactions),
            BudgetView(budget: budget, setBudget: setBudget, deleteBudget: deleteBudget),
            MonthlyChart(transactions: transactions),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () => _showAddTransactionDialog(context),
        ),
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddTransactionDialog(addTransaction: addTransaction);
      },
    );
  }
}

class EditTransactionDialog extends StatefulWidget {
  final Transaction transaction;
  final Function(Transaction) onEdit;

  EditTransactionDialog({required this.transaction, required this.onEdit});

  @override
  _EditTransactionDialogState createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<EditTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String description;
  late double amount;
  late String category;
  late bool isExpense;

  @override
  void initState() {
    super.initState();
    description = widget.transaction.description;
    amount = widget.transaction.amount;
    category = widget.transaction.category;
    isExpense = widget.transaction.isExpense;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Transaction'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              initialValue: description,
              decoration: InputDecoration(labelText: 'Description'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
              onSaved: (value) => description = value!,
            ),
            TextFormField(
              initialValue: amount.toString(),
              decoration: InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
              onSaved: (value) => amount = double.parse(value!),
            ),
            TextFormField(
              initialValue: category,
              decoration: InputDecoration(labelText: 'Category'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a category';
                }
                return null;
              },
              onSaved: (value) => category = value!,
            ),
            SwitchListTile(
              title: Text('Is this an expense?'),
              value: isExpense,
              onChanged: (bool value) {
                setState(() {
                  isExpense = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: Text('Save'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              widget.onEdit(Transaction(
                description: description,
                amount: amount,
                category: category,
                isExpense: isExpense,
                date: widget.transaction.date,
              ));
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final Function(int) deleteTransaction;
  final Function(int, Transaction) editTransaction;

  TransactionList({
    required this.transactions,
    required this.deleteTransaction,
    required this.editTransaction,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(transactions[index].description),
          subtitle: Text(transactions[index].category),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${transactions[index].amount.toStringAsFixed(2)} ${transactions[index].isExpense ? '-' : '+'}',
                style: TextStyle(
                  color: transactions[index].isExpense ? Colors.red : Colors.green,
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showEditTransactionDialog(context, index, transactions[index]),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => deleteTransaction(index),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditTransactionDialog(BuildContext context, int index, Transaction transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditTransactionDialog(
          transaction: transaction,
          onEdit: (updatedTransaction) => editTransaction(index, updatedTransaction),
        );
      },
    );
  }
}

class ExpenseChart extends StatelessWidget {
  final List<Transaction> transactions;

  ExpenseChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    Map<String, double> categoryTotals = {};

    for (var transaction in transactions) {
      if (transaction.isExpense) {
        categoryTotals[transaction.category] = (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      }
    }

    List<PieChartSectionData> sections = categoryTotals.entries.map((entry) {
      return PieChartSectionData(
        color: Colors.primaries[categoryTotals.keys.toList().indexOf(entry.key) % Colors.primaries.length],
        value: entry.value,
        title: '${entry.key}\n${entry.value.toStringAsFixed(2)}',
        radius: 100,
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 0,
      ),
    );
  }
}

class IncomeChart extends StatelessWidget {
  final List<Transaction> transactions;

  IncomeChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    Map<String, double> categoryTotals = {};

    for (var transaction in transactions) {
      if (!transaction.isExpense) {
        categoryTotals[transaction.category] = (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      }
    }

    List<PieChartSectionData> sections = categoryTotals.entries.map((entry) {
      return PieChartSectionData(
        color: Colors.primaries[categoryTotals.keys.toList().indexOf(entry.key) % Colors.primaries.length],
        value: entry.value,
        title: '${entry.key}\n${entry.value.toStringAsFixed(2)}',
        radius: 100,
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 0,
      ),
    );
  }
}

class MonthlyChart extends StatelessWidget {
  final List<Transaction> transactions;

  MonthlyChart({required this.transactions});

  @override
  Widget build(BuildContext context) {
    Map<String, double> monthlyIncome = {};
    Map<String, double> monthlyExpense = {};

    // Memisahkan income dan expense per bulan
    for (var transaction in transactions) {
      String month = "${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}";
      if (transaction.isExpense) {
        monthlyExpense[month] = (monthlyExpense[month] ?? 0) + transaction.amount;
      } else {
        monthlyIncome[month] = (monthlyIncome[month] ?? 0) + transaction.amount;
      }
    }

    List<BarChartGroupData> barGroups = [];

    // Menyesuaikan data income dan expense pada bar chart
    monthlyIncome.forEach((month, income) {
      double expense = monthlyExpense[month] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: int.parse(month.split('-')[1]), // Mengambil bulan
          barRods: [
            BarChartRodData(
              toY: income,
              color: Colors.green,
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: expense,
              color: Colors.red,
              width: 10,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    });

    return BarChart(
      BarChartData(
        maxY: _getMaxY(monthlyIncome, monthlyExpense),
        barGroups: barGroups,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                int month = value.toInt();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(_monthLabel(month)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1000,
              reservedSize: 40,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text('\$${value.toInt()}');
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.grey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String month = _monthLabel(group.x.toInt());
              String category = rod.color == Colors.green ? 'Income' : 'Expense';
              return BarTooltipItem(
                '$month\n$category: \$${rod.toY.toStringAsFixed(2)}',
                TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }

  // Fungsi untuk menentukan skala maksimum grafik
  double _getMaxY(Map<String, double> income, Map<String, double> expense) {
    double maxIncome = income.values.isEmpty ? 0 : income.values.reduce((a, b) => a > b ? a : b);
    double maxExpense = expense.values.isEmpty ? 0 : expense.values.reduce((a, b) => a > b ? a : b);
    return (maxIncome > maxExpense ? maxIncome : maxExpense) + 500; // memberikan margin
  }

  // Fungsi untuk menampilkan label bulan dengan lebih jelas
  String _monthLabel(int month) {
    switch (month) {
      case 1:
        return 'Jan';
      case 2:
        return 'Feb';
      case 3:
        return 'Mar';
      case 4:
        return 'Apr';
      case 5:
        return 'May';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Aug';
      case 9:
        return 'Sep';
      case 10:
        return 'Oct';
      case 11:
        return 'Nov';
      case 12:
        return 'Dec';
      default:
        return '';
    }
  }
}


class MonthlyReport extends StatelessWidget {
  final List<Transaction> transactions;

  MonthlyReport({required this.transactions});

  Map<String, Map<String, double>> _calculateMonthlyData() {
    Map<String, Map<String, double>> monthlyData = {};

    for (var transaction in transactions) {
      String month = "${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}";

      if (!monthlyData.containsKey(month)) {
        monthlyData[month] = {"income": 0.0, "expense": 0.0};
      }

      if (transaction.isExpense) {
        monthlyData[month]!["expense"] = monthlyData[month]!["expense"]! + transaction.amount;
      } else {
        monthlyData[month]!["income"] = monthlyData[month]!["income"]! + transaction.amount;
      }
    }

    return monthlyData;
  }

  @override
  Widget build(BuildContext context) {
    Map<String, Map<String, double>> monthlyData = _calculateMonthlyData();

    return Column(
      children: [
        // Bagian Tabel
        Expanded(
          child: DataTable(
            columns: const <DataColumn>[
              DataColumn(label: Text('Bulan')),
              DataColumn(label: Text('Pemasukan')),
              DataColumn(label: Text('Pengeluaran')),
              DataColumn(label: Text('Total')),
            ],
            rows: monthlyData.entries.map((entry) {
              String month = entry.key;
              double income = entry.value["income"]!;
              double expense = entry.value["expense"]!;
              double total = income - expense;

              return DataRow(cells: [
                DataCell(Text(month)),
                DataCell(Text('\$${income.toStringAsFixed(2)}')),
                DataCell(Text('\$${expense.toStringAsFixed(2)}')),
                DataCell(Text('\$${total.toStringAsFixed(2)}')),
              ]);
            }).toList(),
          ),
        ),
        // Bagian Grafik
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barGroups: monthlyData.entries.map((entry) {
                String month = entry.key;
                double income = entry.value["income"]!;
                double expense = entry.value["expense"]!;

                return BarChartGroupData(
                  x: int.parse(month.split('-')[1]), // Mengambil bulan
                  barRods: [
                    BarChartRodData(
                      toY: income,
                      color: Colors.green,
                      width: 15,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    BarChartRodData(
                      toY: expense,
                      color: Colors.red,
                      width: 15,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      int month = value.toInt();
                      return Text(month.toString());
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BudgetView extends StatelessWidget {
  final Map<String, double> budget;
  final Function(String, double) setBudget;
  final Function(String) deleteBudget;

  BudgetView({required this.budget, required this.setBudget, required this.deleteBudget});

  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: budget.length + 1,
      itemBuilder: (context, index) {
        if (index == budget.length) {
          return ListTile(
            title: Text('Add New Budget Category'),
            trailing: Icon(Icons.add),
            onTap: () => _showAddBudgetDialog(context),
          );
        }
        String category = budget.keys.elementAt(index);
        double amount = budget[category]!;
        return ListTile(
          title: Text(category),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(currencyFormatter.format(amount)),
              IconButton(
                icon: Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _showEditBudgetDialog(context, category, amount),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(context, category),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddBudgetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddBudgetDialog(setBudget: setBudget);
      },
    );
  }

  void _showEditBudgetDialog(BuildContext context, String category, double amount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return EditBudgetDialog(category: category, amount: amount, setBudget: setBudget);
      },
    );
  }

  void _confirmDelete(BuildContext context, String category) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Budget'),
          content: Text('Are you sure you want to delete the budget for "$category"?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Delete'),
              onPressed: () {
                deleteBudget(category);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}


class AddTransactionDialog extends StatefulWidget {
  final Function(Transaction) addTransaction;

  AddTransactionDialog({required this.addTransaction});

  @override
  _AddTransactionDialogState createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  String description = '';
  double amount = 0;
  String category = '';
  bool isExpense = true;
  DateTime? selectedDate;

  final _amountController = TextEditingController();
  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Transaction'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
                onSaved: (value) => description = value!,
              ),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(_sanitizeAmount(value)) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onChanged: (value) {
                  String sanitized = _sanitizeAmount(value);
                  if (sanitized.isEmpty) sanitized = '0';

                  setState(() {
                    amount = double.parse(sanitized);
                    _amountController.value = TextEditingValue(
                      text: currencyFormatter.format(amount),
                      selection: TextSelection.collapsed(offset: currencyFormatter.format(amount).length),
                    );
                  });
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Category'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category';
                  }
                  return null;
                },
                onSaved: (value) => category = value!,
              ),
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date',
                  hintText: selectedDate != null
                      ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                      : 'Select Date',
                ),
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      selectedDate = pickedDate;
                    });
                  }
                },
                validator: (value) {
                  if (selectedDate == null) {
                    return 'Please select a date';
                  }
                  return null;
                },
              ),
              SwitchListTile(
                title: Text('Is this an expense?'),
                value: isExpense,
                onChanged: (bool value) {
                  setState(() {
                    isExpense = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: Text('Add'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              widget.addTransaction(Transaction(
                description: description,
                amount: amount,
                category: category,
                isExpense: isExpense,
                date: selectedDate ?? DateTime.now(),
              ));
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }

  // Fungsi untuk menghapus simbol dan memformat ulang angka
  String _sanitizeAmount(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}

class AddBudgetDialog extends StatefulWidget {
  final Function(String, double) setBudget;

  AddBudgetDialog({required this.setBudget});

  @override
  _AddBudgetDialogState createState() => _AddBudgetDialogState();
}

class _AddBudgetDialogState extends State<AddBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  String category = '';
  double amount = 0;
  final _amountController = TextEditingController();
  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Budget Category'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              decoration: InputDecoration(labelText: 'Category'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a category';
                }
                return null;
              },
              onSaved: (value) => category = value!,
            ),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an amount';
                }
                if (double.tryParse(_sanitizeAmount(value)) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
              onChanged: (value) {
                String sanitized = _sanitizeAmount(value);
                if (sanitized.isEmpty) sanitized = '0';

                setState(() {
                  amount = double.parse(sanitized);
                  _amountController.value = TextEditingValue(
                    text: currencyFormatter.format(amount),
                    selection: TextSelection.collapsed(offset: currencyFormatter.format(amount).length),
                  );
                });
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: Text('Add'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              widget.setBudget(category, amount);
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }

  String _sanitizeAmount(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}


class EditBudgetDialog extends StatefulWidget {
  final String category;
  final double amount;
  final Function(String, double) setBudget;

  EditBudgetDialog({required this.category, required this.amount, required this.setBudget});

  @override
  _EditBudgetDialogState createState() => _EditBudgetDialogState();
}

class _EditBudgetDialogState extends State<EditBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late double amount;
  final _amountController = TextEditingController();
  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    amount = widget.amount;
    _amountController.text = currencyFormatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Budget: ${widget.category}'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _amountController,
          decoration: InputDecoration(labelText: 'Amount'),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            if (double.tryParse(_sanitizeAmount(value)) == null) {
              return 'Please enter a valid number';
            }
            return null;
          },
          onChanged: (value) {
            String sanitized = _sanitizeAmount(value);
            if (sanitized.isEmpty) sanitized = '0';

            setState(() {
              amount = double.parse(sanitized);
              _amountController.value = TextEditingValue(
                text: currencyFormatter.format(amount),
                selection: TextSelection.collapsed(offset: currencyFormatter.format(amount).length),
              );
            });
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: Text('Save'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.setBudget(widget.category, amount);
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }

  String _sanitizeAmount(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }
}


class Transaction {
  final String description;
  final double amount;
  final String category;
  final bool isExpense;
  final DateTime date;

  Transaction({
    required this.description,
    required this.amount,
    required this.category,
    required this.isExpense,
    required this.date,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      description: json['description'],
      amount: json['amount'],
      category: json['category'],
      isExpense: json['isExpense'],
      date: DateTime.parse(json['date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
      'category': category,
      'isExpense': isExpense,
      'date': date.toIso8601String(),
    };
  }
}