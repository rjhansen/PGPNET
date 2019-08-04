/* Copyright © 2017, Robert J. Hansen <rjh@sixdemonbag.org>
 * 
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE. */

using System;
using System.IO;
using System.Net;
using System.Linq;
using System.Text;
using System.Xml.Linq;
using System.Diagnostics;
using System.Text.RegularExpressions;
using Microsoft.Extensions.CommandLineUtils;

namespace UpdatePRR
{
	class Program
	{
		private static readonly string GnuPGPath;
		private static readonly string PGPRulesPath;

		static Program()
		{
			string profileDir = String.Empty;
			switch (Environment.OSVersion.Platform)
			{
				case PlatformID.Win32NT:
					using (var registryKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"Software\GnuPG"))
					{
						GnuPGPath = (String)registryKey.GetValue("Install Directory") + @"\bin\gpg.exe";
					}
					profileDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Thunderbird", "Profiles");
					break;

				case PlatformID.Unix:
					foreach (var p in Environment.GetEnvironmentVariable("PATH").Split(':'))
					{
						var gpg2 = Path.Combine(p, "gpg2");
						var gpg = Path.Combine(p, "gpg");
						if (File.Exists(gpg2)) GnuPGPath = gpg2;
						else if (File.Exists(gpg)) GnuPGPath = gpg;
						if (File.Exists(gpg) || File.Exists(gpg2)) break;
					}
					string[] searchdirs =
					{
						Path.Combine(Environment.GetEnvironmentVariable("HOME"), "Library", "Thunderbird", "Profiles"),
						Path.Combine(Environment.GetEnvironmentVariable("HOME"), ".thunderbird"),
						Path.Combine(Environment.GetEnvironmentVariable("HOME"), ".mozilla-thunderbird")
					};
					foreach (var s in searchdirs)
						if (Directory.Exists(s))
						{
							profileDir = s;
							break;
						}
					break;

				default:
					Console.Error.WriteLine("What OS is this? Aborting.");
					Environment.Exit(1);
					break;
			}

			if (null == GnuPGPath || !File.Exists(GnuPGPath))
			{
				Console.Error.WriteLine("Could not find GnuPG.");
				Environment.Exit(1);
			}

			if (null == profileDir || !Directory.Exists(profileDir))
			{
				Console.Error.WriteLine("Could not find Thunderbird profile folder.");
				Environment.Exit(1);
			}

			string[] subdirs = (from dirname in Directory.GetDirectories(profileDir)
								where dirname.EndsWith(".default", StringComparison.CurrentCulture)
								select dirname).ToArray();
			if (subdirs.Length == 0)
			{
				Console.Error.WriteLine("Could not find any profiles in your Thunderbird folder.");
				Environment.Exit(-1);
			}
			if (subdirs.Length > 1)
			{
				Console.Error.WriteLine("Multiple profiles found.  This application can't handle that — yet.");
				Environment.Exit(1);
			}

			profileDir = subdirs[0];

			if (!Directory.Exists(profileDir))
			{
				Console.Error.WriteLine("Couldn't access " + profileDir);
				Environment.Exit(1);
			}
			if (!File.Exists(Path.Combine(profileDir, "pgprules.xml")))
			{
				Console.Error.WriteLine("No pgprules.xml file found in your profile dir.");
				Environment.Exit(1);
			}
			PGPRulesPath = Path.Combine(profileDir, "pgprules.xml");
		}

		static string[] DownloadIDs(string url)
		{
			if (url == null)
				url = "https://www.dropbox.com/s/9abn35l2xqeqc04/PGPNET%40groups.io.txt?dl=1";
			var wc = new WebClient();
			Console.Out.Write("Fetching member key IDs from Dropbox… ");
			Console.Out.Flush();
			try
			{
				var rows = (from d in Encoding.UTF8.GetString(wc.DownloadData(url)).Split('\n')
							where d.StartsWith("group pgpnet@groups.io=")
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
				Console.Error.WriteLine("couldn't download member list!");
				Environment.Exit(1);
				return null;
			}
		}

		static string DownloadKeys(string url)
		{
			if (url == null)
				url = "https://www.dropbox.com/s/2tu23r92h8taock/PGPNET%40groups.io.asc?dl=1";
			var wc = new WebClient();
			Console.Out.Write("Fetching member keys from Dropbox… ");
			Console.Out.Flush();
			try
			{
				var foo = Encoding.UTF8.GetString(wc.DownloadData(url));
				Console.Out.WriteLine("done.");
				return foo;
			}
			catch
			{
				Console.Error.WriteLine("couldn't download member keys.");
				Environment.Exit(1);
				return null;
			}
		}

		static void ImportKeys(string keys)
		{
			Console.Out.Write("Importing member keys into local keyring… ");
			Console.Out.Flush();
			using (var proc = new Process()
			{
				StartInfo = new ProcessStartInfo()
				{
					FileName = GnuPGPath,
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
			Console.Out.WriteLine("done.");
		}

		static void UpdatePGPRules(string[] ids)
		{
			Console.Out.Write("Updating per-recipient rules… ");
			Console.Out.Flush();
			XDocument xdoc = XDocument.Load(PGPRulesPath);
			var newdoc = new XElement("pgpRuleList",
									  from pgprule in xdoc.Descendants("pgpRule")
									  where pgprule.Attribute("email").Value != "{pgpnet@groups.io}"
									  select pgprule);
			var newrule = new XElement("pgpRule");
			newrule.SetAttributeValue("email", "{pgpnet@groups.io}");
			newrule.SetAttributeValue("encrypt", 2);
			newrule.SetAttributeValue("sign", 2);
			newrule.SetAttributeValue("negateRule", 0);
			newrule.SetAttributeValue("pgpMime", 2);
			newrule.SetAttributeValue("keyId", String.Join(", ", ids));
			newdoc.AddFirst(newrule);

			using (var output = File.CreateText(PGPRulesPath))
			{
				output.Write(newdoc.ToString());
			}
			Console.Out.WriteLine("done.");
		}

		static void Main(string[] args)
		{
			var cmd = new CommandLineApplication();
			var keyopt = cmd.Option("-k | --keyfile <url>",
									"URL of the key file",
									CommandOptionType.SingleValue);
			var idopt = cmd.Option("-i | --idfile <url>",
								   "URL of the membership file",
								   CommandOptionType.SingleValue);
			cmd.OnExecute(() =>
			{
				ImportKeys(DownloadKeys(keyopt.Value()));
				UpdatePGPRules(DownloadIDs(idopt.Value()));
				return 0;
			});
			cmd.HelpOption("-? | -h | --help");
			cmd.Execute(args);
		}
	}
}
