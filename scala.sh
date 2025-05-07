#!/bin/bash

# Exit if any command fails
set -e

# 1. Update package lists and install Java (if not installed)
echo "[*] Updating package lists..."
sudo apt update

echo "[*] Installing OpenJDK 11..."
sudo apt install openjdk-11-jdk -y

# Verify Java installation
echo "[*] Verifying Java installation..."
java -version

# 2. Install Scala
echo "[*] Installing Scala..."
sudo apt install scala -y

# Verify Scala installation
echo "[*] Verifying Scala installation..."
scala -version

# 3. Install Apache Spark
echo "[*] Installing Apache Spark..."

# Download Spark (replace with the latest version if needed)
wget https://downloads.apache.org/spark/spark-3.4.2/spark-3.4.2-bin-hadoop3.tgz

# Extract Spark binary
tar -xvzf spark-3.4.2-bin-hadoop3.tgz

# Move Spark to /opt/spark
sudo mv spark-3.4.2-bin-hadoop3 /opt/spark

# 4. Set up environment variables for Spark
echo "[*] Setting up environment variables for Spark..."
echo -e '\n# Spark Environment\nexport SPARK_HOME=/opt/spark\nexport PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin' >> ~/.bashrc
source ~/.bashrc

# Verify Spark installation
echo "[*] Verifying Spark installation..."
spark-shell --version

# 5. Write the Scala WordCount Program (to a file)
echo "[*] Writing the WordCount.scala program..."

cat <<EOF > WordCount.scala
import org.apache.spark.sql.SparkSession

object WordCount {
  def main(args: Array[String]): Unit = {
    val spark = SparkSession.builder()
      .appName("Simple Word Count")
      .master("local[*]") // Run locally with all cores
      .getOrCreate()

    val sc = spark.sparkContext

    // Input file
    val input = sc.textFile("input.txt")

    // Count word occurrences
    val counts = input
      .flatMap(line => line.split(" "))
      .map(word => (word, 1))
      .reduceByKey(_ + _)

    // Show results
    counts.collect().foreach(println)

    spark.stop()
  }
}
EOF

# 6. Prepare the input file
echo "[*] Preparing input.txt file..."

cat <<EOF > input.txt
hello world hello spark big data with scala and spark
EOF

# 7. Create a shell script to compile, run, and output the results
echo "[*] Creating the run_spark_wordcount.sh script..."

cat <<EOF > run_spark_wordcount.sh
#!/bin/bash

# Exit if any command fails
set -e

# Check for necessary files
if [ ! -f WordCount.scala ]; then
  echo "❌ WordCount.scala not found!"
  exit 1
fi

if [ ! -f input.txt ]; then
  echo "❌ input.txt not found!"
  exit 1
fi

echo "✅ Compiling WordCount.scala..."
scalac -classpath "\$SPARK_HOME/jars/*" WordCount.scala

echo "🚀 Running WordCount with spark-submit..."
spark-submit \
  --class WordCount \
  --master local[*] \
  WordCount*.class

echo "✅ Done."
EOF

# Make the run script executable
chmod +x run_spark_wordcount.sh

# 8. Run the script
echo "[*] Running the WordCount program..."
./run_spark_wordcount.sh

echo "[*] Process complete."
