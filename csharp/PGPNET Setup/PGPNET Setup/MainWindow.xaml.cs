using System;
using System.Linq;
using System.Xml.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows;

namespace PGPNET_Setup
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        async private Task<string> DownloadKeys()
        {
            var url = "https://www.dropbox.com/s/bhpqzxcht527ruu/PGPNET.asc?dl=1";
            var wc = new System.Net.WebClient();
            try
            {
                var data = await wc.DownloadDataTaskAsync(url);
                var foo = Encoding.UTF8.GetString(data);
                return foo;
            }
            catch
            {
                MessageBox.Show("Couldn't download PGPNET files.", "Network error", MessageBoxButton.OK);
                this.Close();
                return null;
            }
        }

        async private Task<string[]> DownloadIDs()
        {
            var url = "https://www.dropbox.com/s/j754hlknhot9sk8/Group%20Line.txt?dl=1";
            var wc = new System.Net.WebClient();
            try
            {
                var data = await wc.DownloadDataTaskAsync(url);
                var rows = (from d in Encoding.UTF8.GetString(data).Split('\n')
                            where d.StartsWith("group pgpnet@yahoogroups.com=")
                            select d).ToArray();
                if (rows.Length != 1)
                {
                    Console.Error.WriteLine("Corrupt membership file");
                    Environment.Exit(1);
                }
                Console.Out.WriteLine("done.");
                var ids = rows[0].Split('=')[1].Trim().Split(' ');

                var rx = new Regex("^0x[A-F0-9]{16}$", RegexOptions.IgnoreCase);
                return (from keyid in ids
                        where rx.IsMatch(keyid)
                        select keyid).ToArray();
            }
            catch
            {
                MessageBox.Show("Couldn't download PGPNET files.", "Network error", MessageBoxButton.OK);
                this.Close();
                return null;
            }
        }

        private void ImportKeys(string keys)
        {
            using (var proc = new System.Diagnostics.Process()
            {
                StartInfo = new System.Diagnostics.ProcessStartInfo()
                {
                    FileName = Controller.GnuPGPath,
                    Arguments = "--no-tty --batch --quiet --import",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    RedirectStandardError = true,
                    RedirectStandardInput = true,
                    RedirectStandardOutput = true
                }
            })
            {
                proc.Start();
                proc.StandardInput.Write(keys);
                proc.StandardInput.Close();
                proc.WaitForExit();
            }
        }

        private void UpdatePGPRules(string[] ids)
        {
            XDocument xdoc = XDocument.Load(Controller.PRRPath);
            var newdoc = new XElement("pgpRuleList",
                                      from pgprule in xdoc.Descendants("pgpRule")
                                      where pgprule.Attribute("email").Value != "{pgpnet@yahoogroups.com}"
                                      select pgprule);
            var newrule = new XElement("pgpRule");
            newrule.SetAttributeValue("email", "{pgpnet@yahoogroups.com}");
            newrule.SetAttributeValue("encrypt", 2);
            newrule.SetAttributeValue("sign", 2);
            newrule.SetAttributeValue("negateRule", 0);
            newrule.SetAttributeValue("pgpMime", 2);
            newrule.SetAttributeValue("keyId", String.Join(", ", ids));
            newdoc.AddFirst(newrule);

            using (var output = System.IO.File.CreateText(Controller.PRRPath))
            {
                output.Write(newdoc.ToString());
            }
        }

        public MainWindow()
        {
            InitializeComponent();
            actionButton.Focus();
        }

        private void quitButton_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }

        async private void actionButton_Click(object sender, RoutedEventArgs e)
        {
            quitButton.IsEnabled = false;
            actionButton.IsEnabled = false;
            var gpgPath = Controller.GnuPGPath;
            findingGnuPG.Value = 1;
            var prrPath = Controller.PRRPath;
            findingEnigmail.Value = 1;
            Controller.AdjustGPGConf();
            configuringGnuPG.Value = 1;
            acquiringData.IsIndeterminate = true;
            var ids = await DownloadIDs();
            var keys = await DownloadKeys();
            acquiringData.IsIndeterminate = false;
            acquiringData.Value = 1;
            ImportKeys(keys);
            UpdatePGPRules(ids);
            configuringEnigmail.Value = 1;
            quitButton.IsEnabled = true;
        }

        private void fileQuit_Click(object sender, RoutedEventArgs e)
        {
            this.Close();
        }

        private void helpPGPNET_Click(object sender, RoutedEventArgs e)
        {

        }

        private void helpAbout_Click(object sender, RoutedEventArgs e)
        {

        }
    }
}
