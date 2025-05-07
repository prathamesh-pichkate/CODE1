#!/bin/bash

# Exit if any command fails
set -e

# 1. Update and Install Java (OpenJDK 11)
echo "[*] Updating package lists..."
sudo apt update

echo "[*] Installing OpenJDK 11..."
sudo apt install openjdk-11-jdk -y

# Verify Java installation
echo "[*] Verifying Java installation..."
java -version

# 2. Install Hadoop
echo "[*] Installing Hadoop..."

# Download Hadoop (change version if needed)
wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz

# Extract Hadoop binary
tar -xvzf hadoop-3.3.6.tar.gz

# Move Hadoop to /opt
sudo mv hadoop-3.3.6 /opt/hadoop

# Set up Hadoop environment variables
echo "[*] Setting up Hadoop environment variables..."

echo -e '\n# Hadoop Environment Variables\nexport HADOOP_HOME=/opt/hadoop\nexport PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' >> ~/.bashrc
source ~/.bashrc

# Verify Hadoop installation
echo "[*] Verifying Hadoop installation..."
hadoop version

# 3. Write the MapReduce WordCount Program to Process Log File (LogCount.scala)
echo "[*] Writing LogCount.scala program..."

cat <<EOF > LogCount.scala
import org.apache.hadoop.conf.Configuration
import org.apache.hadoop.fs.FileSystem
import org.apache.hadoop.fs.Path
import org.apache.hadoop.io.{IntWritable, Text}
import org.apache.hadoop.mapred.{JobConf, JobClient, FileInputFormat, FileOutputFormat}
import org.apache.hadoop.mapred.lib.MultipleOutputs
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat

object LogCount {
  def main(args: Array[String]): Unit = {
    if (args.length != 2) {
      println("Usage: LogCount <input path> <output path>")
      sys.exit(1)
    }

    val conf = new Configuration()
    val job = JobConf()

    // Set the job's input/output paths
    FileInputFormat.setInputPaths(job, new Path(args(0)))
    FileOutputFormat.setOutputPath(job, new Path(args(1)))

    // Define mapper and reducer
    job.setMapperClass(classOf[LogMapper])
    job.setReducerClass(classOf[LogReducer])

    job.setOutputKeyClass(classOf[Text])
    job.setOutputValueClass(classOf[IntWritable])

    // Run the job
    JobClient.runJob(job)
  }

  // Mapper class
  class LogMapper extends Mapper[LongWritable, Text, Text, IntWritable] {
    override def map(key: LongWritable, value: Text, context: Context): Unit = {
      val logLine = value.toString
      val severityPattern = "(INFO|ERROR|DEBUG)".r
      severityPattern.findFirstIn(logLine) match {
        case Some(severity) =>
          context.write(new Text(severity), new IntWritable(1))
        case None =>
          // Ignore lines without a severity level
      }
    }
  }

  // Reducer class
  class LogReducer extends Reducer[Text, IntWritable, Text, IntWritable] {
    override def reduce(key: Text, values: Iterable[IntWritable], context: Context): Unit = {
      val sum = values.map(_.get()).sum
      context.write(key, new IntWritable(sum))
    }
  }
}
EOF

# 4. Prepare the input log file
echo "[*] Preparing input log file..."

cat <<EOF > input.log
INFO: This is an info log.
ERROR: Something went wrong.
DEBUG: Debugging the application.
INFO: Another info log.
ERROR: Another error occurred.
EOF

# 5. Create a script to compile, run the job, and clean up
echo "[*] Creating the run_logcount.sh script..."

cat <<EOF > run_logcount.sh
#!/bin/bash

# Exit if any command fails
set -e

# Check for necessary files
if [ ! -f LogCount.scala ]; then
  echo "❌ LogCount.scala not found!"
  exit 1
fi

if [ ! -f input.log ]; then
  echo "❌ input.log not found!"
  exit 1
fi

# Compile the Scala file with Hadoop libraries
echo "✅ Compiling LogCount.scala..."
scalac -classpath "\$HADOOP_HOME/share/hadoop/common/hadoop-common-3.3.6.jar:\$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-client-core-3.3.6.jar" LogCount.scala

# Create a JAR file from the compiled class files
echo "✅ Creating JAR file..."
jar -cvf LogCount.jar LogCount*.class

# Run the MapReduce job using Hadoop
echo "🚀 Running MapReduce job..."
hadoop jar LogCount.jar LogCount input.log output

# Show the output
echo "[*] Showing output..."
hadoop fs -cat output/part-*

echo "✅ Done."
EOF

# Make the run script executable
chmod +x run_logcount.sh

# 6. Run the script to compile and execute the MapReduce job
echo "[*] Running the LogCount program..."
./run_logcount.sh

echo "[*] Process complete."

